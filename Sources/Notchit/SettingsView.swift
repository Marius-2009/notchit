import AppKit
import SwiftUI
import NotchitCore

final class SettingsWindowController {
    private var window: NSWindow?
    private let settings: SettingsStore
    private let controller: NotchController

    init(settings: SettingsStore, controller: NotchController) {
        self.settings = settings
        self.controller = controller
    }

    func show() {
        if window == nil {
            let view = SettingsView(controller: controller).environmentObject(settings)
            let w = NSWindow(contentViewController: NSHostingController(rootView: view))
            w.title = "Réglages de Notchit"
            w.styleMask = [.titled, .closable, .miniaturizable]
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    let controller: NotchController
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        TabView {
            GeneralTab().tabItem { Label("Comportement", systemImage: "cursorarrow.motionlines") }
            SizeTab(controller: controller).tabItem { Label("Taille", systemImage: "rectangle.expand.vertical") }
            AppearanceTab().tabItem { Label("Apparence", systemImage: "paintpalette") }
            ModulesTab().tabItem { Label("Modules", systemImage: "square.grid.2x2") }
            ShortcutTab().tabItem { Label("Raccourci", systemImage: "command") }
            PrivacyTab().tabItem { Label("Confidentialité", systemImage: "lock.shield") }
            BackupTab().tabItem { Label("Sauvegarde", systemImage: "externaldrive") }
        }
        .padding(20)
        .frame(width: 640, height: 500)
    }
}

private struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step = 1.0
    var unit = ""
    var decimals = 0

    var body: some View {
        LabeledContent(title) {
            HStack {
                Slider(value: $value, in: range, step: step)
                Text(String(format: "%.\(decimals)f", value) + unit)
                    .monospacedDigit()
                    .frame(width: 58, alignment: .trailing)
            }
        }
    }
}

private struct GeneralTab: View {
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        Form {
            Section("Démarrage") {
                Toggle("Lancer Notchit à l'ouverture de session", isOn: $settings.value.launchAtLogin)
                if let message = settings.loginItemMessage {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Ouverture") {
                Toggle("Ouvrir au survol", isOn: $settings.value.openOnHover)
                Toggle("Ouvrir d'un clic sur l'encoche", isOn: $settings.value.openOnClick)
                SliderRow(title: "Délai avant ouverture", value: $settings.value.openDelay, range: NotchSettings.openDelayRange, step: 0.05, unit: " s", decimals: 2)
                SliderRow(title: "Délai avant fermeture", value: $settings.value.closeDelay, range: NotchSettings.closeDelayRange, step: 0.05, unit: " s", decimals: 2)
                SliderRow(title: "Marge de la zone de survol", value: $settings.value.hoverMargin, range: NotchSettings.hoverMarginRange, unit: " pt")
                Toggle("S'ouvrir un instant quand on branche le chargeur", isOn: $settings.value.peekOnPlugIn)
            }
            Section("Animations et retours") {
                SliderRow(title: "Vitesse du ressort", value: $settings.value.springResponse, range: NotchSettings.responseRange, step: 0.01, unit: " s", decimals: 2)
                SliderRow(title: "Amortissement", value: $settings.value.springDamping, range: NotchSettings.dampingRange, step: 0.01, decimals: 2)
                Toggle("Réduire les animations", isOn: $settings.value.reduceMotion)
                Toggle("Retour haptique à l'ouverture", isOn: $settings.value.haptics)
                Text("Limité : macOS ne fait vibrer que les trackpads Force Touch, et seulement quand un doigt est posé dessus. Sans effet à la souris.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("À propos") {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev")
                if let url = Links.support {
                    LabeledContent("Notchit est gratuit et sans publicité") {
                        Button("Soutenir le projet") { NSWorkspace.shared.open(url) }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct SizeTab: View {
    let controller: NotchController
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        Form {
            Section("Encoche ouverte") {
                SliderRow(title: "Largeur", value: $settings.value.openWidth, range: NotchSettings.widthRange, unit: " pt")
                SliderRow(title: "Hauteur", value: $settings.value.openHeight, range: NotchSettings.heightRange, unit: " pt")
                SliderRow(title: "Arrondi", value: $settings.value.openRadius, range: NotchSettings.openRadiusRange, unit: " pt")
                SliderRow(title: "Marges intérieures", value: $settings.value.padding, range: NotchSettings.paddingRange, unit: " pt")
            }
            Section("Encoche fermée") {
                SliderRow(title: "Arrondi", value: $settings.value.closedRadius, range: NotchSettings.closedRadiusRange, unit: " pt")
                Toggle("Pochette et visualiseur pendant la musique", isOn: $settings.value.musicWhenClosed)
            }
            Section {
                HStack {
                    Button("Redimensionner à la souris") { controller.setEditing(true) }
                    Button("Taille d'origine") { settings.resetSize() }
                }
                if !controller.hasHardwareNotch {
                    Text("Pas d'encoche sur cet écran : Notchit dessine une encoche virtuelle en haut au centre.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct AppearanceTab: View {
    @EnvironmentObject var settings: SettingsStore

    private func colorBinding(_ path: WritableKeyPath<ThemeColors, RGBA>) -> Binding<Color> {
        Binding(
            get: { settings.value.custom[keyPath: path].color },
            set: { settings.value.custom[keyPath: path] = RGBA($0) }
        )
    }

    var body: some View {
        Form {
            Section("Thème") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 10) {
                    ForEach(ThemeID.allCases) { t in
                        ThemeSwatch(theme: t, selected: settings.value.theme == t)
                            .onTapGesture { settings.value.theme = t }
                    }
                }
                .padding(.vertical, 4)
                Toggle("Ombre sous l'encoche ouverte", isOn: $settings.value.shadow)
            }
            if settings.value.theme == .perso {
                Section("Couleurs personnalisées") {
                    ColorPicker("Fond", selection: colorBinding(\.background), supportsOpacity: true)
                    ColorPicker("Texte", selection: colorBinding(\.foreground), supportsOpacity: false)
                    ColorPicker("Texte secondaire", selection: colorBinding(\.secondary), supportsOpacity: false)
                    ColorPicker("Accent", selection: colorBinding(\.accent), supportsOpacity: false)
                    Toggle("Effet verre derrière le fond", isOn: $settings.value.custom.glass)
                    let ratio = settings.value.custom.foreground.contrast(with: settings.value.custom.background)
                    Text(String(format: "Contraste texte / fond : %.1f:1", ratio) + (ratio < 4.5 ? ", trop faible pour bien lire" : ""))
                        .font(.caption)
                        .foregroundStyle(ratio < 4.5 ? Color.red : Color.secondary)
                    Button("Partir du thème Noir") { settings.value.custom = ThemeID.noir.colors(custom: settings.value.custom) }
                }
            }
            Text("L'encoche fermée reste noire pour se fondre avec celle de l'écran.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }
}

private struct ThemeSwatch: View {
    let theme: ThemeID
    let selected: Bool
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        let c = theme.colors(custom: settings.value.custom)
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(c.glass ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(c.background.color))
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(c.background.color)
                HStack(spacing: 6) {
                    Capsule().fill(c.foreground.color).frame(width: 30, height: 6)
                    Circle().fill(c.accent.color).frame(width: 10, height: 10)
                }
            }
            .frame(height: 44)
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(selected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: selected ? 3 : 1))
            Text(theme.name).font(.caption)
        }
        .contentShape(Rectangle())
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityLabel("Thème \(theme.name)")
    }
}

private struct ModulesTab: View {
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Cochez les modules à afficher et glissez-les pour changer leur ordre. Batterie et heure vont dans la ligne du haut. Trois pages : Musique (lecture en cours), Agenda (calendrier et minuteur), Fichiers et miroir (étagère et miroir).")
                .font(.callout)
                .foregroundStyle(.secondary)
            List {
                ForEach($settings.value.modules) { $m in
                    HStack {
                        Image(systemName: "line.3.horizontal").foregroundStyle(.tertiary)
                        Image(systemName: m.kind.symbol).frame(width: 22)
                        Toggle(m.kind.name, isOn: $m.enabled)
                        Spacer()
                        Text(m.kind.page.map { "page " + $0.name } ?? "ligne du haut").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .onMove { settings.value.modules.move(fromOffsets: $0, toOffset: $1) }
            }
            .listStyle(.bordered)
            Form {
                Section("Pages") {
                    Toggle("Changer de page en balayant le trackpad à deux doigts", isOn: $settings.value.swipePages)
                }
                Section("Minuteur et Pomodoro") {
                    Toggle("Son à la fin", isOn: $settings.value.timerSound)
                    Stepper("Travail : \(settings.value.pomodoro.work) min", value: $settings.value.pomodoro.work, in: 1...120)
                    Stepper("Pause courte : \(settings.value.pomodoro.shortBreak) min", value: $settings.value.pomodoro.shortBreak, in: 1...60)
                    Stepper("Grande pause : \(settings.value.pomodoro.longBreak) min", value: $settings.value.pomodoro.longBreak, in: 1...90)
                    Stepper("Sessions avant la grande pause : \(settings.value.pomodoro.rounds)", value: $settings.value.pomodoro.rounds, in: 1...12)
                    Toggle("Enchaîner automatiquement travail et pauses", isOn: $settings.value.autoNextPomodoro)
                }
                Section("Miroir et calendrier") {
                    Text("Le miroir n'allume la caméra qu'au clic et l'éteint quand l'encoche se ferme. Le calendrier lit les agendas du Mac, après votre accord, sans rien envoyer.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .frame(height: 300)
        }
    }
}

private struct PrivacyTab: View {
    @EnvironmentObject var settings: SettingsStore
    @State private var cleared = false

    private func open(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") { NSWorkspace.shared.open(url) }
    }

    var body: some View {
        Form {
            Section("Lecture en cours") {
                Toggle("Lire ce qui joue dans tout le système (navigateurs compris)", isOn: $settings.value.systemMedia)
                Text("Activé : Notchit lit le titre, l'artiste, la pochette et la position via un petit module exécuté par /usr/bin/perl, programme signé par Apple. Rien ne sort du Mac. Désactivé : seuls Spotify et Musique sont lus, par AppleScript, avec l'accord de macOS.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Autorisations macOS") {
                LabeledContent("Caméra (miroir)") { Button("Ouvrir") { open("Privacy_Camera") } }
                LabeledContent("Calendriers") { Button("Ouvrir") { open("Privacy_Calendars") } }
                LabeledContent("Automatisation (Spotify, Musique)") { Button("Ouvrir") { open("Privacy_Automation") } }
                Text("La caméra ne s'allume qu'au clic sur le miroir et s'éteint à la fermeture de l'encoche. Aucune image n'est enregistrée. Aucune donnée n'est envoyée sur Internet ; seule la pochette Spotify est téléchargée, en HTTPS, depuis les serveurs de Spotify.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Données enregistrées sur ce Mac") {
                Text("Réglages, chemins des fichiers de l'étagère (pas les fichiers eux-mêmes), état du minuteur. Tout est dans les préférences de fr.livio-studio.notchit.")
                    .font(.caption).foregroundStyle(.secondary)
                Button(cleared ? "Effacé" : "Vider l'étagère et le minuteur") {
                    NotificationCenter.default.post(name: .notchitClearData, object: nil)
                    cleared = true
                }
                .disabled(cleared)
            }
        }
        .formStyle(.grouped)
    }
}

extension Notification.Name {
    static let notchitClearData = Notification.Name("fr.livio-studio.notchit.clear")
}

private struct ShortcutTab: View {
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        Form {
            Section("Ouvrir ou fermer l'encoche au clavier") {
                Toggle("Raccourci actif", isOn: $settings.value.shortcutEnabled)
                Picker("Touche", selection: $settings.value.shortcut.key) {
                    ForEach(Shortcut.keys, id: \.self) { Text($0).tag($0) }
                }
                Toggle("⌘ Commande", isOn: $settings.value.shortcut.command)
                Toggle("⌥ Option", isOn: $settings.value.shortcut.option)
                Toggle("⌃ Contrôle", isOn: $settings.value.shortcut.control)
                Toggle("⇧ Majuscule", isOn: $settings.value.shortcut.shift)
                LabeledContent("Raccourci", value: settings.value.shortcut.display)
                Text("Il faut au moins ⌘, ⌥ ou ⌃. Sans eux, Notchit revient à ⌥⌘N.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct BackupTab: View {
    @EnvironmentObject var settings: SettingsStore
    @State private var message = ""
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section("Fichier de configuration") {
                Text("Tous les réglages tiennent dans un fichier JSON lisible : on peut le copier sur un autre Mac ou le modifier à la main.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Exporter…") { settings.exportToFile() }
                    Button("Importer…") { message = settings.importFromFile() ?? "" }
                }
                if !message.isEmpty { Text(message).foregroundStyle(.red) }
            }
            Section("Réinitialiser") {
                Button("Revenir aux réglages d'origine", role: .destructive) { confirmReset = true }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Revenir aux réglages d'origine ?", isPresented: $confirmReset) {
            Button("Réinitialiser", role: .destructive) { settings.reset() }
        } message: {
            Text("Taille, thème, modules et raccourci reprennent leurs valeurs de départ. L'étagère n'est pas vidée.")
        }
    }
}
