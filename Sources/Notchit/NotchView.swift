import SwiftUI
import UniformTypeIdentifiers
import NotchitCore


struct NotchView: View {
    let controller: NotchController
    @EnvironmentObject var state: NotchState
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var music: MusicModel
    @EnvironmentObject var battery: BatteryModel
    @EnvironmentObject var shelf: ShelfModel
    @EnvironmentObject var timer: TimerModel
    @EnvironmentObject var mirror: MirrorModel
    @State private var dropTargeted = false

    private var s: NotchSettings { settings.value }
    private var c: ThemeColors { settings.colors }

    private var musicVisible: Bool { music.isPlaying && s.musicWhenClosed && s.isEnabled(.music) }
    private var timerVisible: Bool { timer.isActive && s.isEnabled(.timer) }
    private var activity: Bool { musicVisible || timerVisible }

    private var size: CGSize {
        if state.expanded { return CGSize(width: s.openWidth, height: s.openHeight) }
        let n = state.notchSize
        return CGSize(width: NotchGeometry.closedWidth(notch: n, activity: activity), height: n.height)
    }

    private var radius: CGFloat { state.expanded ? s.openRadius : s.closedRadius }

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(bottomLeadingRadius: radius, bottomTrailingRadius: radius, style: .continuous)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                background
                if state.expanded && !state.editing {
                    open.transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                } else if !state.expanded {
                    closed.transition(.opacity)
                }
                if state.editing {
                    EditOverlay(controller: controller, radius: radius)
                }
            }
            .frame(width: size.width, height: size.height)
            .clipShape(shape)
            .scaleEffect(state.pressed ? 0.97 : 1, anchor: .top)
            .shadow(color: .black.opacity(state.expanded && s.shadow ? 0.35 : 0), radius: 18, y: 8)
            .onDrop(of: [UTType.fileURL], isTargeted: $dropTargeted) { providers in
                guard s.isEnabled(.shelf) else { return false }
                load(providers)
                return true
            }
            .onChange(of: dropTargeted) { _, on in
                if on, s.isEnabled(.shelf) { controller.show(page: .files) }
            }
            Spacer(minLength: 0)
        }
        .frame(width: NotchGeometry.panelSize.width, height: NotchGeometry.panelSize.height, alignment: .top)
        .environment(\.colorScheme, c.background.luminance > 0.5 ? .light : .dark)
    }

    @ViewBuilder private var background: some View {
        if !state.expanded {
            shape.fill(Color.black)
        } else if c.glass {
            ZStack(alignment: .top) {
                shape.fill(.ultraThinMaterial)
                shape.fill(c.background.color)
                Rectangle().fill(Color.black).frame(height: state.notchSize.height)
            }
        } else {
            shape.fill(c.background.color)
        }
    }

    private var closed: some View {
        HStack(spacing: 0) {
            if activity {
                Group {
                    if musicVisible && !timerVisible {
                        Artwork(image: music.artwork, size: 22, corner: 6)
                    } else {
                        Image(systemName: timer.mode.symbol)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(TimerStyle.orange)
                            .symbolEffect(.pulse, isActive: !timer.isRunning)
                    }
                }
                .frame(width: 40, alignment: .leading)
                .padding(.leading, 12)
                Spacer(minLength: state.notchSize.width)
                Group {
                    if timerVisible {
                        Text(timer.label)
                            .font(.system(size: 14, weight: .semibold).monospacedDigit())
                            .foregroundStyle(TimerStyle.orange.opacity(timer.isRunning ? 1 : 0.55))
                            .lineLimit(1)
                            .fixedSize()
                    } else {
                        Visualizer(active: music.isPlaying, color: c.accent.color)
                            .frame(width: 22, height: 14)
                    }
                }
                .frame(width: 40, alignment: .trailing)
                .padding(.trailing, 12)
            }
        }
        .frame(height: state.notchSize.height)
    }

    private var header: [ModuleKind] { s.orderedEnabled.filter(\.inHeader) }
    private var pages: [NotchPage] { s.pages }
    private var page: NotchPage? { pages.contains(state.page) ? state.page : pages.first }

    private var headerHeight: CGFloat { max(state.notchSize.height - 8, 18) }
    private var bottomInset: CGFloat { min(26, max(14, CGFloat(s.padding) * 0.75)) }
    private var headerGap: CGFloat { 12 }
    private var headerInset: CGFloat { min(CGFloat(s.padding), max(14, CGFloat(s.openRadius) * 0.5)) }
    private var notchGap: CGFloat { state.notchSize.width + 16 }
    private var ear: CGFloat { max(0, (CGFloat(s.openWidth) - notchGap) / 2 - headerInset) }
    private var contentHeight: CGFloat { max(40, s.openHeight - headerHeight - headerGap - bottomInset) }

    private var open: some View {
        VStack(spacing: headerGap) {
            HStack(spacing: 0) {
                HStack(spacing: 0) {
                    if pages.count > 1 {
                        PageTabs(pages: pages, current: page, room: ear) { controller.show(page: $0) }
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: ear)
                Spacer(minLength: notchGap)
                HStack(spacing: 8) {
                    Spacer(minLength: 0)
                    ForEach(header) { kind in
                        switch kind {
                        case .battery: BatteryBadge()
                        case .clock: ClockBadge()
                        default: EmptyView()
                        }
                    }
                    SettingsButton { controller.openSettings() }
                }
                .frame(width: ear)
                .clipped()
            }
            .frame(height: headerHeight)
            .padding(.horizontal, headerInset)

            ZStack {
                if let page {
                    content(page)
                        .id(page)
                        .transition(.asymmetric(
                            insertion: .move(edge: page == .media ? .leading : .trailing).combined(with: .opacity),
                            removal: .move(edge: page == .media ? .leading : .trailing).combined(with: .opacity)))
                } else {
                    Text("Aucun module actif : Réglages, onglet Modules")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(c.secondary.color)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: contentHeight, alignment: .top)
            .clipped()
        }
        .padding(.bottom, bottomInset)
        .foregroundStyle(c.foreground.color)
        .tint(c.accent.color)
    }

    @ViewBuilder private func content(_ page: NotchPage) -> some View {
        switch page {
        case .media:
            MediaPage().padding(.horizontal, s.padding)
        case .agenda:
            GeometryReader { g in agenda(width: g.size.width, height: g.size.height) }
        case .files:
            GeometryReader { g in files(width: g.size.width, height: g.size.height) }
                .animation(settings.animation, value: mirror.running)
                .animation(settings.animation, value: shelf.previewing)
        }
    }

    @ViewBuilder private func agenda(width: CGFloat, height: CGFloat) -> some View {
        let mods = s.modules(on: .agenda)
        let p = CGFloat(s.padding)
        let inner = width - 2 * p
        let both = mods.count == 2
        let timerWidth = both ? min(240, max(150, inner * 0.46)) : inner
        HStack(alignment: .top, spacing: 16) {
            ForEach(mods) { kind in
                if kind == .calendar {
                    CalendarCard(maxItems: max(1, Int((height - 22 - 20) / 38)))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    TimerCard().frame(width: timerWidth, height: height)
                }
            }
        }
        .padding(.horizontal, p)
        .frame(width: width, height: height, alignment: .top)
    }

    @ViewBuilder private func files(width: CGFloat, height: CGFloat) -> some View {
        let mods = s.modules(on: .files)
        let p = CGFloat(s.padding)
        let inner = width - 2 * p
        let mirrorOn = mods.contains(.mirror)
        let shelfOn = mods.contains(.shelf)
        if shelfOn, let url = shelf.previewing {
            ShelfPreview(url: url)
                .padding(.horizontal, p)
                .frame(width: width, height: height)
                .transition(.scale(scale: 0.85).combined(with: .opacity))
        } else if mirrorOn && (mirror.running || mirror.starting || !shelfOn) {
            MirrorCard()
                .frame(width: inner, height: height)
                .padding(.horizontal, p)
                .transition(.scale(scale: 0.6, anchor: .trailing).combined(with: .opacity))
        } else {
            HStack(alignment: .top, spacing: 16) {
                if shelfOn {
                    Shelf(targeted: dropTargeted, height: height)
                }
                if mirrorOn {
                    MirrorCard().frame(width: min(height, inner * 0.45), height: min(height, inner * 0.45))
                }
            }
            .padding(.horizontal, p)
            .frame(width: width, height: height, alignment: .top)
            .transition(.opacity)
        }
    }

    private func load(_ providers: [NSItemProvider]) {
        for p in providers {
            _ = p.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                DispatchQueue.main.async { shelf.add([url]) }
            }
        }
    }
}

struct SettingsButton: View {
    let action: () -> Void
    @EnvironmentObject var settings: SettingsStore
    @State private var hover = false

    var body: some View {
        let c = settings.colors
        Button(action: action) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(hover ? c.foreground.color : c.secondary.color)
                .frame(width: 22, height: 22)
                .background(Circle().fill(c.foreground.color.opacity(hover ? 0.14 : 0.06)))
                .rotationEffect(.degrees(hover ? 30 : 0))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.easeOut(duration: 0.18)) { hover = h } }
        .help("Réglages")
        .accessibilityLabel("Réglages")
    }
}

struct PageTabs: View {
    let pages: [NotchPage]
    let current: NotchPage?
    var room: CGFloat = 200
    let select: (NotchPage) -> Void
    @EnvironmentObject var settings: SettingsStore
    @Namespace private var ns

    private var tabWidth: CGFloat {
        let n = CGFloat(max(1, pages.count))
        return max(20, min(30, (room - 4 - 2 * (n - 1)) / n))
    }

    var body: some View {
        let c = settings.colors
        HStack(spacing: 2) {
            ForEach(pages) { p in
                Button { select(p) } label: {
                    Image(systemName: p.symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: tabWidth, height: 20)
                        .foregroundStyle(p == current ? c.foreground.color : c.secondary.color)
                        .background {
                            if p == current {
                                Capsule().fill(c.foreground.color.opacity(0.16)).matchedGeometryEffect(id: "tab", in: ns)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .help(p.name)
                .accessibilityLabel("Page \(p.name)")
                .accessibilityAddTraits(p == current ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Capsule().fill(c.foreground.color.opacity(0.06)))
    }
}

struct MediaPage: View {
    @EnvironmentObject var music: MusicModel
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        GeometryReader { g in layout(g.size) }
    }

    @ViewBuilder private func layout(_ size: CGSize) -> some View {
        let c = settings.colors
        let art = max(48, min(108, size.height - 6, size.width * 0.3))
        if let source = music.player {
            HStack(spacing: art > 80 ? 18 : 12) {
                ZStack(alignment: .bottomTrailing) {
                    Artwork(image: music.artwork, size: art, corner: art * 0.17, video: source.isBrowser)
                    if let icon = source.icon {
                        Image(nsImage: icon).resizable().frame(width: art * 0.28, height: art * 0.28)
                            .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
                            .offset(x: art * 0.07, y: art * 0.07)
                            .accessibilityHidden(true)
                    }
                }
                .padding(.trailing, 6)
                VStack(alignment: .leading, spacing: art > 80 ? 8 : 4) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(music.title).font(.system(size: 17, weight: .semibold)).lineLimit(1)
                            Text(music.artist.isEmpty ? source.name : music.artist)
                                .font(.system(size: 13)).foregroundStyle(c.secondary.color).lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        Visualizer(active: music.isPlaying, color: c.accent.color).frame(width: 22, height: 16)
                    }
                    if music.duration > 0 {
                        Progress(position: music.position, duration: music.duration) { music.seek(to: $0) }
                    }
                    HStack(spacing: art > 80 ? 30 : 16) {
                        Spacer()
                        Control(symbol: "backward.fill", size: 19, label: "Précédent") { music.previous() }
                        Control(symbol: music.isPlaying ? "pause.fill" : "play.fill", size: 27, label: music.isPlaying ? "Pause" : "Lecture") { music.playPause() }
                        Control(symbol: "forward.fill", size: 19, label: "Suivant") { music.next() }
                        Spacer()
                    }
                }
            }
            .frame(width: size.width, height: size.height)
        } else {
            Placeholder(symbol: "play.slash", text: "Rien en lecture\nSpotify, Musique ou une vidéo dans le navigateur")
        }
    }
}

struct Progress: View {
    let position: Double
    let duration: Double
    var seek: ((Double) -> Void)?
    @EnvironmentObject var settings: SettingsStore
    @State private var drag: Double?

    private func format(_ t: Double) -> String {
        let s = max(0, Int(t.rounded()))
        return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60) : String(format: "%d:%02d", s / 60, s % 60)
    }

    var body: some View {
        let c = settings.colors
        let shown = drag ?? position
        HStack(spacing: 8) {
            Text(format(shown))
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(c.foreground.color.opacity(0.18))
                    Capsule().fill(c.foreground.color)
                        .frame(width: duration > 0 ? g.size.width * min(1, max(0, shown / duration)) : 0)
                }
                .frame(height: drag == nil ? 4 : 7)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        guard seek != nil, duration > 0 else { return }
                        drag = min(1, max(0, v.location.x / g.size.width)) * duration
                    }
                    .onEnded { _ in
                        if let d = drag { seek?(d) }
                        drag = nil
                    })
            }
            .frame(height: 12)
            .animation(.easeOut(duration: 0.15), value: drag == nil)
            Text("-" + format(max(0, duration - shown)))
        }
        .font(.system(size: 10, weight: .medium).monospacedDigit())
        .foregroundStyle(c.secondary.color)
    }
}

struct EditOverlay: View {
    let controller: NotchController
    let radius: CGFloat
    @EnvironmentObject var settings: SettingsStore
    @State private var start: CGSize?

    private var c: ThemeColors { settings.colors }

    var body: some View {
        ZStack(alignment: .bottom) {
            UnevenRoundedRectangle(bottomLeadingRadius: radius, bottomTrailingRadius: radius, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                .foregroundStyle(c.accent.color)
            VStack(spacing: 10) {
                Text("\(Int(settings.value.openWidth)) × \(Int(settings.value.openHeight))")
                    .font(.system(size: 22, weight: .semibold).monospacedDigit())
                Text("Glissez les poignées pour redimensionner")
                    .font(.system(size: 12))
                    .foregroundStyle(c.secondary.color)
                HStack(spacing: 10) {
                    Button("Taille d'origine") { withAnimation(settings.animation) { settings.resetSize() } }
                    Button("Terminé") { controller.setEditing(false) }
                        .keyboardShortcut(.defaultAction)
                }
                .controlSize(.regular)
            }
            .foregroundStyle(c.foreground.color)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack {
                handle(horizontal: -1)
                Spacer()
                handle(horizontal: 0)
                Spacer()
                handle(horizontal: 1)
            }
            .padding(.horizontal, max(6, radius * 0.45))
            .padding(.bottom, max(6, radius * 0.18))
        }
    }

    private func handle(horizontal: CGFloat) -> some View {
        Circle()
            .fill(c.accent.color)
            .frame(width: 16, height: 16)
            .overlay(Circle().stroke(c.foreground.color, lineWidth: 2))
            .contentShape(Rectangle().inset(by: -10))
            .onHover { inside in
                if inside { (horizontal == 0 ? NSCursor.resizeUpDown : NSCursor.crosshair).push() } else { NSCursor.pop() }
            }
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { g in
                        let base = start ?? CGSize(width: settings.value.openWidth, height: settings.value.openHeight)
                        if start == nil { start = base }
                        var v = settings.value
                        v.openWidth = base.width + 2 * horizontal * g.translation.width
                        v.openHeight = base.height + g.translation.height
                        settings.value = v
                    }
                    .onEnded { _ in start = nil }
            )
            .accessibilityLabel(horizontal == 0 ? "Poignée de hauteur" : "Poignée de taille")
    }
}

struct BatteryBadge: View {
    @EnvironmentObject var battery: BatteryModel
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        if battery.hasBattery {
            HStack(spacing: 5) {
                Image(systemName: battery.symbol)
                    .foregroundStyle(battery.pluggedIn ? Color.green : (battery.level <= 20 ? Color.red : settings.colors.foreground.color))
                Text("\(battery.level) %").monospacedDigit()
            }
            .font(.system(size: 12, weight: .semibold))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Batterie \(battery.level) pour cent\(battery.pluggedIn ? ", branchée" : "")")
        }
    }
}

struct ClockBadge: View {
    var body: some View {
        TimelineView(.everyMinute) { context in
            Text(context.date, format: .dateTime.weekday(.abbreviated).day().hour().minute())
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
        }
    }
}

struct Control: View {
    let symbol: String
    let size: CGFloat
    let label: String
    let action: () -> Void
    @EnvironmentObject var settings: SettingsStore
    @State private var hover = false
    @State private var down = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .frame(width: 34, height: 28)
                .background(Circle().fill(settings.colors.foreground.color.opacity(hover ? 0.12 : 0)).frame(width: 34, height: 34))
                .scaleEffect(down ? 0.86 : 1)
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .simultaneousGesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in withAnimation(.easeOut(duration: 0.08)) { down = true } }
            .onEnded { _ in withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { down = false } })
        .accessibilityLabel(label)
    }
}

struct Artwork: View {
    let image: NSImage?
    let size: CGFloat
    let corner: CGFloat
    var video = false

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color.white.opacity(0.1)
                    Image(systemName: video ? "play.rectangle.fill" : "music.note").font(.system(size: size * 0.4)).foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .accessibilityHidden(true)
    }
}

struct Visualizer: View {
    let active: Bool
    var color: Color = .white

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.12, paused: !active)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<4, id: \.self) { i in
                    let v = active ? 0.3 + 0.7 * abs(sin(t * (2.1 + Double(i) * 0.9) + Double(i))) : 0.2
                    Capsule()
                        .fill(color)
                        .frame(width: 3)
                        .scaleEffect(x: 1, y: v, anchor: .center)
                }
            }
            .animation(.easeInOut(duration: 0.12), value: t)
        }
        .accessibilityHidden(true)
    }
}

struct Shelf: View {
    @EnvironmentObject var shelf: ShelfModel
    @EnvironmentObject var settings: SettingsStore
    let targeted: Bool
    var height: CGFloat = 50

    var body: some View {
        let c = settings.colors
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                .foregroundStyle(targeted ? c.accent.color : c.foreground.color.opacity(0.18))
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(c.foreground.color.opacity(targeted ? 0.08 : 0.03)))
            if shelf.items.isEmpty {
                Label("Glissez des fichiers ici", systemImage: "tray.and.arrow.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(c.secondary.color)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(shelf.items, id: \.self) { url in
                            ShelfItem(url: url, side: max(26, min(84, height - (height >= 70 ? 34 : 14))))
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(maxHeight: .infinity)
                }
            }
        }
        .frame(height: height)
        .scaleEffect(targeted ? 1.02 : 1)
        .animation(.easeOut(duration: 0.15), value: targeted)
    }
}

struct ShelfItem: View {
    @EnvironmentObject var shelf: ShelfModel
    @EnvironmentObject var settings: SettingsStore
    let url: URL
    let side: CGFloat
    @State private var hover = false

    var body: some View {
        let c = settings.colors
        let thumb = shelf.thumbnails[url]
        VStack(spacing: 4) {
            ZStack {
                if let thumb {
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: side, height: side)
                        .clipShape(RoundedRectangle(cornerRadius: side * 0.14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: side * 0.14, style: .continuous)
                            .stroke(c.foreground.color.opacity(0.12), lineWidth: 1))
                } else {
                    Image(nsImage: shelf.icon(for: url))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: side * 0.8, height: side * 0.8)
                }
            }
            .frame(width: side, height: side)
            .scaleEffect(hover ? 1.05 : 1)
            .shadow(color: .black.opacity(hover ? 0.35 : 0), radius: 6, y: 3)
            if side >= 40 {
                Text(url.deletingPathExtension().lastPathComponent)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(c.secondary.color)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(width: side + 8)
            }
        }
        .contentShape(Rectangle())
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hover = h } }
        .help(url.lastPathComponent)
        .accessibilityLabel(url.lastPathComponent)
        .accessibilityAddTraits(.isButton)
        .onDrag { NSItemProvider(object: url as NSURL) }
        .simultaneousGesture(TapGesture(count: 2).onEnded { NSWorkspace.shared.open(url) })
        .simultaneousGesture(TapGesture(count: 1).onEnded {
            withAnimation(settings.animation) { shelf.previewing = url }
        })
        .contextMenu {
            Button("Aperçu") { withAnimation(settings.animation) { shelf.previewing = url } }
            Button("Ouvrir") { NSWorkspace.shared.open(url) }
            Button("Afficher dans le Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            Divider()
            Button("Retirer de l'étagère") { shelf.remove(url) }
            Button("Vider l'étagère") { shelf.clear() }
        }
    }
}

struct ShelfPreview: View {
    let url: URL
    @EnvironmentObject var shelf: ShelfModel
    @EnvironmentObject var settings: SettingsStore

    private var index: Int? { shelf.items.firstIndex(of: url) }

    var body: some View {
        let c = settings.colors
        let image = shelf.fullImage(url) ?? shelf.thumbnails[url] ?? shelf.icon(for: url)
        HStack(spacing: 12) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onDrag { NSItemProvider(object: url as NSURL) }
                .simultaneousGesture(TapGesture(count: 2).onEnded { NSWorkspace.shared.open(url) })
            VStack(alignment: .leading, spacing: 6) {
                Text(url.lastPathComponent)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(2)
                    .truncationMode(.middle)
                if let size = image.representations.first.map({ "\($0.pixelsWide) × \($0.pixelsHigh)" }), shelf.isImage(url) {
                    Text(size).font(.system(size: 10).monospacedDigit()).foregroundStyle(c.secondary.color)
                }
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    Control(symbol: "chevron.left", size: 12, label: "Précédent") { step(-1) }
                        .disabled((index ?? 0) == 0)
                    Control(symbol: "chevron.right", size: 12, label: "Suivant") { step(1) }
                        .disabled((index ?? 0) >= shelf.items.count - 1)
                }
                HStack(spacing: 6) {
                    Control(symbol: "arrow.up.forward.app", size: 12, label: "Ouvrir") { NSWorkspace.shared.open(url) }
                    Control(symbol: "xmark", size: 12, label: "Fermer l'aperçu") {
                        withAnimation(settings.animation) { shelf.previewing = nil }
                    }
                }
            }
            .frame(width: 96, alignment: .leading)
        }
    }

    private func step(_ d: Int) {
        guard let i = index, shelf.items.indices.contains(i + d) else { return }
        withAnimation(.snappy) { shelf.previewing = shelf.items[i + d] }
    }
}
