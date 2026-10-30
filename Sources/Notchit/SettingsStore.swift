import AppKit
import ServiceManagement
import SwiftUI
import NotchitCore

final class SettingsStore: ObservableObject {
    private static let key = "settings.v1"

    @Published var value: NotchSettings {
        didSet {
            let c = value.clamped()
            if c != value { value = c; return }
            save()
        }
    }

    @Published private(set) var loginItemMessage: String?

    func applyLoginItem() {
        let service = SMAppService.mainApp
        do {
            if value.launchAtLogin, service.status != .enabled { try service.register() }
            if !value.launchAtLogin, service.status == .enabled { try service.unregister() }
            loginItemMessage = service.status == .requiresApproval
                ? "À valider dans Réglages Système > Général > Ouverture." : nil
        } catch {
            loginItemMessage = "Impossible pour l'instant : placez Notchit dans le dossier Applications, puis réessayez."
        }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key), let s = try? NotchSettings.decode(data) {
            value = s
        } else {
            value = NotchSettings()
        }
        save()
    }

    var colors: ThemeColors { value.colors }

    func reset() { value = NotchSettings() }

    func resetSize() {
        let d = NotchSettings()
        value.openWidth = d.openWidth
        value.openHeight = d.openHeight
    }

    var animation: Animation {
        if value.reduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            return .easeOut(duration: 0.12)
        }
        return .spring(response: value.springResponse, dampingFraction: value.springDamping)
    }

    func exportToFile() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "notchit-reglages.json"
        panel.allowedContentTypes = [.json]
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url, let data = try? value.encoded() else { return }
        try? data.write(to: url)
    }

    @discardableResult
    func importFromFile() -> String? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        do {
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            guard size > 0, size < 256_000 else { return "Fichier refusé : une configuration Notchit fait moins de 256 Ko." }
            value = try NotchSettings.decode(Data(contentsOf: url))
            return nil
        } catch {
            return "Fichier illisible : ce n'est pas une configuration Notchit."
        }
    }

    private func save() {
        if let data = try? value.encoded() { UserDefaults.standard.set(data, forKey: Self.key) }
    }
}

extension RGBA {
    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }

    init(_ color: Color) {
        let c = NSColor(color).usingColorSpace(.sRGB) ?? .black
        self.init(Double(c.redComponent), Double(c.greenComponent), Double(c.blueComponent), Double(c.alphaComponent))
    }
}
