import AppKit
import Combine
import SwiftUI
import NotchitCore

final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class NotchState: ObservableObject {
    @Published var expanded = false
    @Published var editing = false
    @Published var pressed = false
    @Published var notchSize = CGSize(width: 185, height: 32)
    @Published var page: NotchPage = .media
}

final class NotchController {
    let state = NotchState()
    let settings: SettingsStore
    private lazy var music = MusicModel(system: settings.value.systemMedia)
    private let battery = BatteryModel()
    private let shelf = ShelfModel()
    private let timer = TimerModel()
    private let calendar = CalendarModel()
    private let mirror = MirrorModel()
    private var panel: NotchPanel?
    private var monitors: [Any] = []
    private var openWork: DispatchWorkItem?
    private var closeWork: DispatchWorkItem?
    private var watch: Timer?
    private var pinned = false
    private var swipe: CGFloat = 0
    private var swiped = false
    private var hotKey: HotKey?
    private var bag = Set<AnyCancellable>()
    var onShortcutFailure: ((String) -> Void)?
    var onOpenSettings: (() -> Void)?

    init(settings: SettingsStore) {
        self.settings = settings
    }

    private var s: NotchSettings { settings.value }

    private var activityVisible: Bool {
        (music.isPlaying && s.musicWhenClosed && s.isEnabled(.music)) || (timer.isActive && s.isEnabled(.timer))
    }

    func show() {
        let panel = NotchPanel(
            contentRect: NSRect(origin: .zero, size: NotchGeometry.panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.isMovable = false
        panel.ignoresMouseEvents = true
        panel.acceptsMouseMovedEvents = true
        panel.setAccessibilityLabel("Notchit")

        let root = NotchView(controller: self)
            .environmentObject(state)
            .environmentObject(settings)
            .environmentObject(music)
            .environmentObject(battery)
            .environmentObject(shelf)
            .environmentObject(timer)
            .environmentObject(calendar)
            .environmentObject(mirror)
        let host = NSHostingView(rootView: root)
        host.frame = NSRect(origin: .zero, size: NotchGeometry.panelSize)
        panel.contentView = host
        self.panel = panel

        place()
        panel.orderFrontRegardless()

        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            self?.place()
        }

        let moves: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        if let g = NSEvent.addGlobalMonitorForEvents(matching: moves, handler: { [weak self] _ in self?.track() }) {
            monitors.append(g)
        }
        if let l = NSEvent.addLocalMonitorForEvents(matching: moves, handler: { [weak self] e in self?.track(); return e }) {
            monitors.append(l)
        }
        if let w = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel, handler: { [weak self] e in
            self?.scroll(e) ?? false ? nil : e
        }) {
            monitors.append(w)
        }
        if let c = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown, handler: { [weak self] _ in self?.globalClick() }) {
            monitors.append(c)
        }
        timer.plan = { [weak self] in self?.s.pomodoro ?? PomodoroPlan() }
        timer.autoNext = { [weak self] in self?.s.autoNextPomodoro ?? true }
        timer.onFinish = { [weak self] _ in
            guard let self else { return }
            if self.s.timerSound { NSSound(named: "Glass")?.play() }
            self.page(.agenda)
            self.peek()
        }
        battery.onPlugIn = { [weak self] in
            guard let self, self.s.peekOnPlugIn else { return }
            self.peek()
        }

        settings.$value
            .map { ($0.systemMedia, $0.launchAtLogin) }
            .removeDuplicates { $0 == $1 }
            .sink { [weak self] system, _ in
                self?.music.setSystemMedia(system)
                self?.settings.applyLoginItem()
            }
            .store(in: &bag)
        NotificationCenter.default.addObserver(forName: .notchitClearData, object: nil, queue: .main) { [weak self] _ in
            self?.shelf.clear()
            self?.timer.cancel()
        }

        hotKey = HotKey { [weak self] in DispatchQueue.main.async { self?.toggle() } }
        settings.$value
            .map { ($0.shortcutEnabled, $0.shortcut) }
            .removeDuplicates { $0 == $1 }
            .sink { [weak self] enabled, shortcut in
                guard let self else { return }
                if !(self.hotKey?.register(enabled ? shortcut : nil) ?? true) {
                    self.onShortcutFailure?("Le raccourci \(shortcut.display) est déjà pris par une autre application.")
                }
            }
            .store(in: &bag)
    }

    private var screen: NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
    }

    var hasHardwareNotch: Bool { (screen?.safeAreaInsets.top ?? 0) > 0 }

    private func place() {
        guard let screen, let panel else { return }
        let f = screen.frame
        var notch = CGSize(width: 185, height: 32)
        if screen.safeAreaInsets.top > 0,
           let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            notch = CGSize(width: f.width - left.width - right.width, height: screen.safeAreaInsets.top)
        } else {
            notch.height = max(24, NSStatusBar.system.thickness)
        }
        state.notchSize = notch
        panel.setFrame(NotchGeometry.panelFrame(screen: f), display: true)
    }

    private func hotRect() -> NSRect {
        guard let screen else { return .zero }
        return NotchGeometry.hotRect(screen: screen.frame, notch: state.notchSize, expanded: state.expanded,
                                     activity: activityVisible, settings: s)
    }

    private func track() {
        guard !state.editing else { return }
        let inside = hotRect().contains(NSEvent.mouseLocation)
        if inside {
            closeWork?.cancel()
            closeWork = nil
            if state.expanded {
                pinned = false
            } else if s.openOnHover, openWork == nil {
                if s.openDelay <= 0 {
                    setExpanded(true)
                } else {
                    let work = DispatchWorkItem { [weak self] in
                        guard let self else { return }
                        self.openWork = nil
                        if self.hotRect().contains(NSEvent.mouseLocation) { self.setExpanded(true) }
                    }
                    openWork = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + s.openDelay, execute: work)
                }
            }
        } else {
            openWork?.cancel()
            openWork = nil
            if state.expanded, !pinned, closeWork == nil {
                let work = DispatchWorkItem { [weak self] in
                    guard let self else { return }
                    self.closeWork = nil
                    if !self.pinned, !self.state.editing, !self.hotRect().contains(NSEvent.mouseLocation) {
                        self.setExpanded(false)
                    }
                }
                closeWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + s.closeDelay, execute: work)
            }
        }
    }

    private func globalClick() {
        guard !state.editing else { return }
        let inside = hotRect().contains(NSEvent.mouseLocation)
        if !state.expanded, inside, s.openOnClick {
            flashPress()
            pinned = true
            setExpanded(true)
        } else if state.expanded, !inside, pinned {
            pinned = false
            setExpanded(false)
        }
    }

    private func flashPress() {
        withAnimation(.easeOut(duration: 0.08)) { state.pressed = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            withAnimation(.easeOut(duration: 0.18)) { self?.state.pressed = false }
        }
    }

    func show(page: NotchPage) {
        guard state.page != page else { return }
        withAnimation(settings.animation) { state.page = page }
        if s.haptics { NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now) }
    }

    private func page(_ p: NotchPage) {
        if s.pages.contains(p) { state.page = p }
    }

    private func scroll(_ e: NSEvent) -> Bool {
        guard state.expanded, !state.editing, s.swipePages, s.pages.count > 1, e.hasPreciseScrollingDeltas else { return false }
        if e.phase == .began { swipe = 0; swiped = false }
        guard abs(e.scrollingDeltaX) > abs(e.scrollingDeltaY) || swipe != 0 else { return false }
        swipe += e.scrollingDeltaX
        if !swiped, abs(swipe) > 40 {
            swiped = true
            let pages = s.pages
            let i = pages.firstIndex(of: state.page) ?? 0
            let j = swipe < 0 ? min(pages.count - 1, i + 1) : max(0, i - 1)
            show(page: pages[j])
        }
        if e.phase == .ended || e.phase == .cancelled { swipe = 0; swiped = false }
        return true
    }

    func openSettings() {
        pinned = false
        setExpanded(false)
        onOpenSettings?()
    }

    func toggle() {
        guard !state.editing else { return }
        if state.expanded {
            pinned = false
            setExpanded(false)
        } else {
            pinned = true
            setExpanded(true)
        }
    }

    func setEditing(_ value: Bool) {
        openWork?.cancel()
        closeWork?.cancel()
        openWork = nil
        closeWork = nil
        withAnimation(settings.animation) { state.editing = value }
        if value {
            pinned = true
            setExpanded(true)
        } else {
            pinned = false
            track()
        }
    }

    private func setExpanded(_ value: Bool) {
        guard state.expanded != value || value else { return }
        if value, !state.expanded, s.haptics {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
        withAnimation(settings.animation) { state.expanded = value }
        panel?.ignoresMouseEvents = !value
        watch?.invalidate()
        watch = nil
        if !value { mirror.stop(); shelf.previewing = nil }
        if value, s.isEnabled(.calendar) { calendar.refresh() }
        if value {
            watch = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in self?.track() }
        }
    }

    private func peek() {
        guard !state.expanded else { return }
        setExpanded(true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let self, !self.pinned, !self.state.editing else { return }
            if !self.hotRect().contains(NSEvent.mouseLocation) { self.setExpanded(false) }
        }
    }
}
