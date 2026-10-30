import AppKit
import SwiftUI

@main
struct NotchitApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

enum Links {
    static let support = URL(string: "https://github.com/sponsors/Marius-2009")
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = SettingsStore()
    private var controller: NotchController?
    private var settingsWindow: SettingsWindowController?
    private var statusItem: NSStatusItem?
    private var toggleItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = NotchController(settings: settings)
        controller.onShortcutFailure = { message in
            let alert = NSAlert()
            alert.messageText = "Raccourci indisponible"
            alert.informativeText = message + " Choisissez-en un autre dans Réglages, onglet Raccourci."
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
        controller.show()
        self.controller = controller
        settingsWindow = SettingsWindowController(settings: settings, controller: controller)
        controller.onOpenSettings = { [weak self] in self?.openSettings() }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "capsule.fill", accessibilityDescription: "Notchit")
        let menu = NSMenu()
        menu.delegate = self
        let toggle = NSMenuItem(title: "Ouvrir l'encoche", action: #selector(toggleNotch), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)
        toggleItem = toggle
        let edit = NSMenuItem(title: "Redimensionner l'encoche", action: #selector(editNotch), keyEquivalent: "")
        edit.target = self
        menu.addItem(edit)
        menu.addItem(.separator())
        let prefs = NSMenuItem(title: "Réglages…", action: #selector(openSettings), keyEquivalent: ",")
        prefs.target = self
        menu.addItem(prefs)
        if Links.support != nil {
            let support = NSMenuItem(title: "Soutenir Notchit…", action: #selector(openSupport), keyEquivalent: "")
            support.target = self
            menu.addItem(support)
        }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quitter Notchit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item

        let args = ProcessInfo.processInfo.arguments
        if args.contains("--reglages") { openSettings() }
        if args.contains("--edition") { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { controller.setEditing(true) } }
    }

    func menuWillOpen(_ menu: NSMenu) {
        let s = settings.value
        let open = controller?.state.expanded ?? false
        toggleItem?.title = (open ? "Fermer l'encoche" : "Ouvrir l'encoche") + (s.shortcutEnabled ? "  " + s.shortcut.display : "")
    }

    @objc private func toggleNotch() { controller?.toggle() }
    @objc private func editNotch() { controller?.setEditing(true) }
    @objc private func openSettings() { settingsWindow?.show() }
    @objc private func openSupport() { if let url = Links.support { NSWorkspace.shared.open(url) } }
}
