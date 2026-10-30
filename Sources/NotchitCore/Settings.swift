import CoreGraphics
import Foundation

public enum ModuleKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case battery, clock, music, calendar, timer, mirror, shelf

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .battery: return "Batterie"
        case .clock: return "Heure et date"
        case .music: return "Lecture en cours"
        case .calendar: return "Calendrier"
        case .timer: return "Minuteur"
        case .mirror: return "Miroir"
        case .shelf: return "Étagère"
        }
    }

    public var symbol: String {
        switch self {
        case .battery: return "battery.75percent"
        case .clock: return "clock"
        case .music: return "music.note"
        case .calendar: return "calendar"
        case .timer: return "timer"
        case .mirror: return "camera"
        case .shelf: return "tray"
        }
    }

    public var inHeader: Bool { self == .battery || self == .clock }

    public var page: NotchPage? {
        if inHeader { return nil }
        switch self {
        case .music: return .media
        case .calendar, .timer: return .agenda
        default: return .files
        }
    }
}

public enum NotchPage: String, Codable, CaseIterable, Identifiable, Sendable {
    case media, agenda, files

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .media: return "Musique"
        case .agenda: return "Agenda"
        case .files: return "Fichiers et miroir"
        }
    }

    public var symbol: String {
        switch self {
        case .media: return "music.note"
        case .agenda: return "calendar"
        case .files: return "folder.fill"
        }
    }
}

public struct ModuleEntry: Codable, Equatable, Identifiable, Sendable {
    public var kind: ModuleKind
    public var enabled: Bool
    public var id: String { kind.rawValue }

    public init(_ kind: ModuleKind, _ enabled: Bool = true) {
        self.kind = kind
        self.enabled = enabled
    }
}

public struct Shortcut: Codable, Equatable, Sendable {
    public var key: String
    public var command: Bool
    public var option: Bool
    public var control: Bool
    public var shift: Bool

    public init(key: String, command: Bool = true, option: Bool = true, control: Bool = false, shift: Bool = false) {
        self.key = key
        self.command = command
        self.option = option
        self.control = control
        self.shift = shift
    }

    public static let keys: [String] = (65...90).map { String(UnicodeScalar($0)!) } + (0...9).map(String.init)

    private static let codes: [String: UInt32] = [
        "A": 0, "S": 1, "D": 2, "F": 3, "H": 4, "G": 5, "Z": 6, "X": 7, "C": 8, "V": 9,
        "B": 11, "Q": 12, "W": 13, "E": 14, "R": 15, "Y": 16, "T": 17, "1": 18, "2": 19,
        "3": 20, "4": 21, "6": 22, "5": 23, "9": 25, "7": 26, "8": 28, "0": 29, "O": 31,
        "U": 32, "I": 34, "P": 35, "L": 37, "J": 38, "K": 40, "N": 45, "M": 46
    ]

    public var keyCode: UInt32? { Self.codes[key.uppercased()] }

    public var hasModifier: Bool { command || option || control }

    public var isValid: Bool { keyCode != nil && hasModifier }

    public var display: String {
        (control ? "⌃" : "") + (option ? "⌥" : "") + (shift ? "⇧" : "") + (command ? "⌘" : "") + key.uppercased()
    }
}

public struct NotchSettings: Codable, Equatable, Sendable {
    public var openOnHover = true
    public var openOnClick = true
    public var openDelay = 0.0
    public var closeDelay = 0.25
    public var hoverMargin = 6.0
    public var peekOnPlugIn = true
    public var haptics = true

    public var openWidth = 680.0
    public var openHeight = 230.0
    public var openRadius = 28.0
    public var closedRadius = 10.0
    public var padding = 22.0

    public var springResponse = 0.38
    public var springDamping = 0.78
    public var reduceMotion = false

    public var theme = ThemeID.noir
    public var custom = ThemeID.noir.colors(custom: ThemeColors(background: RGBA(0, 0, 0), foreground: RGBA(1, 1, 1), secondary: RGBA(0.6, 0.6, 0.6), accent: RGBA(0.2, 0.84, 0.42)))
    public var shadow = true
    public var musicWhenClosed = true
    public var timerSound = true
    public var swipePages = true
    public var timerLast = 25 * 60
    public var pomodoro = PomodoroPlan()
    public var autoNextPomodoro = true
    public var systemMedia = true
    public var launchAtLogin = false

    public var modules: [ModuleEntry] = [.init(.battery), .init(.clock, false), .init(.music), .init(.calendar), .init(.timer), .init(.mirror), .init(.shelf)]

    public var shortcutEnabled = true
    public var shortcut = Shortcut(key: "N")

    public init() {}

    public static let widthRange = 440.0...760.0
    public static let heightRange = 180.0...300.0
    public static let openRadiusRange = 8.0...48.0
    public static let closedRadiusRange = 0.0...20.0
    public static let paddingRange = 10.0...40.0
    public static let openDelayRange = 0.0...2.0
    public static let closeDelayRange = 0.0...3.0
    public static let hoverMarginRange = 0.0...30.0
    public static let responseRange = 0.15...1.0
    public static let dampingRange = 0.4...1.0

    public var colors: ThemeColors { theme.colors(custom: custom) }

    public func isEnabled(_ kind: ModuleKind) -> Bool {
        modules.first { $0.kind == kind }?.enabled ?? false
    }

    public var orderedEnabled: [ModuleKind] { modules.filter(\.enabled).map(\.kind) }

    public var pages: [NotchPage] {
        NotchPage.allCases.filter { page in orderedEnabled.contains { $0.page == page } }
    }

    public func modules(on page: NotchPage) -> [ModuleKind] {
        orderedEnabled.filter { $0.page == page }
    }

    public func clamped() -> NotchSettings {
        func c(_ v: Double, _ r: ClosedRange<Double>) -> Double { v.isFinite ? min(r.upperBound, max(r.lowerBound, v)) : r.lowerBound }
        var s = self
        s.openWidth = c(openWidth, Self.widthRange)
        s.openHeight = c(openHeight, Self.heightRange)
        s.openRadius = c(openRadius, Self.openRadiusRange)
        s.closedRadius = c(closedRadius, Self.closedRadiusRange)
        s.padding = c(padding, Self.paddingRange)
        s.openDelay = c(openDelay, Self.openDelayRange)
        s.closeDelay = c(closeDelay, Self.closeDelayRange)
        s.hoverMargin = c(hoverMargin, Self.hoverMarginRange)
        s.springResponse = c(springResponse, Self.responseRange)
        s.springDamping = c(springDamping, Self.dampingRange)
        var seen = Set<ModuleKind>()
        s.modules = modules.filter { seen.insert($0.kind).inserted }
        for kind in ModuleKind.allCases where !seen.contains(kind) { s.modules.append(ModuleEntry(kind, false)) }
        s.timerLast = min(23 * 3600 + 59 * 60 + 59, max(1, timerLast))
        s.pomodoro = pomodoro.clamped()
        if !s.shortcut.isValid { s.shortcut = Shortcut(key: "N") }
        return s
    }

    public func encoded() throws -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try e.encode(self)
    }

    public static func decode(_ data: Data) throws -> NotchSettings {
        let base = try JSONSerialization.jsonObject(with: NotchSettings().encoded()) as? [String: Any] ?? [:]
        guard let incoming = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CocoaError(.coderReadCorrupt)
        }
        let merged = base.merging(incoming) { _, new in new }
        let json = try JSONSerialization.data(withJSONObject: merged)
        return try JSONDecoder().decode(NotchSettings.self, from: json).clamped()
    }
}

public enum NotchGeometry {
    public static let panelSize = CGSize(width: 900, height: 470)

    public static func closedWidth(notch: CGSize, activity: Bool) -> Double {
        notch.width + (activity ? 104 : 0)
    }

    public static func hotRect(screen: CGRect, notch: CGSize, expanded: Bool, activity: Bool, settings s: NotchSettings) -> CGRect {
        if expanded {
            let m = 12.0
            return CGRect(x: screen.midX - s.openWidth / 2 - m, y: screen.maxY - s.openHeight - m,
                          width: s.openWidth + 2 * m, height: s.openHeight + m)
        }
        let w = closedWidth(notch: notch, activity: activity) + 2 * s.hoverMargin + 8
        let h = notch.height + s.hoverMargin
        return CGRect(x: screen.midX - w / 2, y: screen.maxY - h, width: w, height: h)
    }

    public static func panelFrame(screen: CGRect) -> CGRect {
        CGRect(x: screen.midX - panelSize.width / 2, y: screen.maxY - panelSize.height,
               width: panelSize.width, height: panelSize.height)
    }
}
