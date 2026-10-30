import Foundation

public struct RGBA: Codable, Equatable, Sendable {
    public var r: Double
    public var g: Double
    public var b: Double
    public var a: Double

    public init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    public init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8, let v = UInt64(s, radix: 16) else { return nil }
        if s.count == 6 {
            self.init(Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255)
        } else {
            self.init(Double((v >> 24) & 0xFF) / 255, Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255)
        }
    }

    public var hex: String {
        func c(_ x: Double) -> Int { Int((min(1, max(0, x)) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", c(r), c(g), c(b))
    }

    public var luminance: Double {
        func lin(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    public func contrast(with other: RGBA) -> Double {
        let l1 = max(luminance, other.luminance)
        let l2 = min(luminance, other.luminance)
        return (l1 + 0.05) / (l2 + 0.05)
    }
}

public struct ThemeColors: Codable, Equatable, Sendable {
    public var background: RGBA
    public var foreground: RGBA
    public var secondary: RGBA
    public var accent: RGBA
    public var glass: Bool

    public init(background: RGBA, foreground: RGBA, secondary: RGBA, accent: RGBA, glass: Bool = false) {
        self.background = background
        self.foreground = foreground
        self.secondary = secondary
        self.accent = accent
        self.glass = glass
    }
}

public enum ThemeID: String, Codable, CaseIterable, Identifiable, Sendable {
    case noir, graphite, minuit, foret, sable, verre, perso

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .noir: return "Noir"
        case .graphite: return "Graphite"
        case .minuit: return "Minuit"
        case .foret: return "Forêt"
        case .sable: return "Sable"
        case .verre: return "Verre"
        case .perso: return "Personnalisé"
        }
    }

    public func colors(custom: ThemeColors) -> ThemeColors {
        switch self {
        case .noir:
            return ThemeColors(background: RGBA(0, 0, 0), foreground: RGBA(1, 1, 1), secondary: RGBA(0.62, 0.62, 0.64), accent: RGBA(0.20, 0.84, 0.42))
        case .graphite:
            return ThemeColors(background: RGBA(0.11, 0.11, 0.12), foreground: RGBA(0.96, 0.96, 0.97), secondary: RGBA(0.62, 0.62, 0.66), accent: RGBA(1.00, 0.62, 0.04))
        case .minuit:
            return ThemeColors(background: RGBA(0.05, 0.06, 0.13), foreground: RGBA(0.93, 0.94, 1.00), secondary: RGBA(0.60, 0.63, 0.78), accent: RGBA(0.55, 0.62, 1.00))
        case .foret:
            return ThemeColors(background: RGBA(0.06, 0.11, 0.08), foreground: RGBA(0.93, 0.97, 0.93), secondary: RGBA(0.60, 0.70, 0.62), accent: RGBA(0.56, 0.86, 0.48))
        case .sable:
            return ThemeColors(background: RGBA(0.95, 0.93, 0.89), foreground: RGBA(0.13, 0.12, 0.10), secondary: RGBA(0.38, 0.35, 0.31), accent: RGBA(0.78, 0.33, 0.20))
        case .verre:
            return ThemeColors(background: RGBA(0.04, 0.04, 0.05, 0.55), foreground: RGBA(1, 1, 1), secondary: RGBA(0.80, 0.80, 0.84), accent: RGBA(0.40, 0.80, 1.00), glass: true)
        case .perso:
            return custom
        }
    }
}
