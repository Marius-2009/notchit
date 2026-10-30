# Guide de Notchit

Ce guide explique comment Notchit est construit, comment le modifier et comment retirer une fonctionnalité qui ne vous plaît pas. Il suppose que vous savez ouvrir un terminal ; il ne suppose pas que vous connaissez Swift.

## 1. Construire et lancer

Il faut un Mac sous macOS 14 ou plus récent et les outils de développement d'Apple (`xcode-select --install` suffit, Xcode complet n'est pas obligatoire).

```
cd notchit                  dossier du projet
./build.sh                 construit build/Notchit.app
open build/Notchit.app     lance l'application
swift test                 lance les tests
```

Avant de relancer après une modification, quittez l'ancienne version : menu de l'encoche (icône en forme de capsule dans la barre des menus), « Quitter Notchit ».

Arguments utiles pour tester : `open build/Notchit.app --args --reglages --edition` ouvre directement la fenêtre de réglages et le mode redimensionnement.

## 2. Comment c'est rangé

```
Package.swift               description du projet pour Swift
build.sh                    construit l'application, l'icône, le module média, la signature
Sources/NotchitCore/        la logique pure, sans interface, couverte par les tests
  Settings.swift            tous les réglages, leurs bornes, les modules, les pages
  Theme.swift               les thèmes et le calcul de contraste
  Countdown.swift           minuteur, chronomètre, Pomodoro, sauvegarde du minuteur
Sources/Notchit/            l'application
  NotchitApp.swift          démarrage, menu de la barre des menus
  NotchController.swift     la fenêtre de l'encoche : ouverture, fermeture, survol, raccourci, pages
  NotchView.swift           ce qu'on voit : encoche fermée, onglets, pages Musique et Fichiers, étagère
  Cards.swift               cartes de la page Agenda (calendrier, minuteur et ses roues) et du miroir
  SettingsView.swift        la fenêtre de réglages et ses onglets
  SettingsStore.swift       lecture et écriture des réglages, export et import, lancement au démarrage
  MusicModel.swift          lecture en cours (module système, ou AppleScript en secours)
  CalendarModel.swift       lecture des agendas du Mac
  TimerModel.swift          minuteur, Pomodoro et chronomètre en marche
  MirrorModel.swift         caméra du miroir
  ShelfModel.swift          fichiers de l'étagère et leurs vignettes
  BatteryModel.swift        batterie
  HotKey.swift              raccourci clavier global
Helper/MediaBridge.m        petit module qui lit « ce qui joue » sur le Mac (voir SECURITY.md)
Resources/                  icône et autorisations de signature
Tools/make-icon.swift       dessine l'icône ; à relancer si vous la changez
Tests/                      tests de NotchitCore
```

Règle de base : ce qui se calcule (bornes, durées, géométrie, cycles Pomodoro) va dans `NotchitCore` avec un test ; ce qui s'affiche ou parle au système va dans `Sources/Notchit`.

## 3. Les modules

Chaque module se coupe sans toucher au code : Réglages, onglet Modules, décocher. Un module décoché ne s'affiche plus et, pour la caméra, ne s'allume jamais.

| Module | Page | Ce qu'il utilise |
|---|---|---|
| Batterie | ligne du haut | IOKit, rien à autoriser |
| Heure et date | ligne du haut | rien |
| Lecture en cours | Musique | module système ou AppleScript (autorisation « Automatisation ») |
| Calendrier | Agenda | EventKit (autorisation « Calendriers ») |
| Minuteur, Pomodoro, chrono | Agenda | rien |
| Miroir | Fichiers et miroir | caméra (autorisation « Caméra »), seulement au clic |
| Étagère | Fichiers et miroir | Quick Look pour les vignettes |

Une page dont tous les modules sont décochés disparaît des onglets.

## 4. Retirer complètement une fonctionnalité du code

Pour chaque module, voici tout ce qu'il faut enlever. Après chaque retrait : `swift build`, puis corriger les erreurs restantes (le compilateur indique chaque ligne qui parlait encore du module), puis `swift test` et `./build.sh`.

Dans tous les cas, retirez aussi le cas correspondant dans `ModuleKind` (`Sources/NotchitCore/Settings.swift`) : dans l'énumération, dans `name`, `symbol`, `page`, et dans la liste `modules` par défaut. Les réglages déjà enregistrés qui citent ce module sont ignorés au chargement.

**Lecture en cours**
- Supprimer `Sources/Notchit/MusicModel.swift` et `Helper/MediaBridge.m`.
- `build.sh` : supprimer la fonction `bridge`, la boucle qui l'appelle, la vérification du fichier `MediaBridge.dylib` et la ligne `codesign` qui le signe ; retirer la clé `NSAppleEventsUsageDescription`.
- `Resources/Notchit.entitlements` : retirer `com.apple.security.automation.apple-events`.
- `NotchView.swift` : retirer `MediaPage`, `Progress`, `Visualizer`, `Artwork`, la partie musique de `closed`.
- `NotchController.swift` : retirer `music`, `activityVisible` côté musique, la mise à jour de `systemMedia`.
- `Settings.swift` : retirer `musicWhenClosed`, `systemMedia` ; `SettingsView.swift` : la section « Lecture en cours » de l'onglet Confidentialité.

**Calendrier**
- Supprimer `CalendarModel.swift`, et dans `Cards.swift` les vues `CalendarCard` et `EventRow`.
- `build.sh` : retirer `NSCalendarsFullAccessUsageDescription` et `NSCalendarsUsageDescription` ; entitlements : `com.apple.security.personal-information.calendars`.
- `NotchController.swift` : retirer `calendar` et l'appel `calendar.refresh()`.

**Minuteur**
- Supprimer `TimerModel.swift` ; dans `Cards.swift` : `TimerCard`, `ModePicker`, `TimerWheels`, `WheelColumn`, `TimerStyle`, `RoundButton` ; dans `NotchitCore` : `Countdown.swift` et ses tests.
- `NotchView.swift` : la partie minuteur de `closed` ; `NotchController.swift` : `timer` et `onFinish`.
- `Settings.swift` : `timerSound`, `timerLast`, `pomodoro`, `autoNextPomodoro`.

**Miroir**
- Supprimer `MirrorModel.swift` et, dans `Cards.swift`, `MirrorCard`.
- `build.sh` : retirer `NSCameraUsageDescription` ; entitlements : `com.apple.security.device.camera`.
- `NotchView.swift` : la branche miroir de `files(...)` ; `NotchController.swift` : `mirror` et `mirror.stop()`.

**Étagère**
- Supprimer `ShelfModel.swift` et, dans `NotchView.swift`, `Shelf`, `ShelfItem`, `ShelfPreview`, le `onDrop` et `dropTargeted`.
- `NotchController.swift` : `shelf` ; `SettingsView.swift` : le bouton « Vider l'étagère et le minuteur ».

**Batterie** : supprimer `BatteryModel.swift`, `BatteryBadge`, `battery` et `peekOnPlugIn`. **Heure** : supprimer `ClockBadge`.

## 5. Ajouter un module

1. Ajouter un cas à `ModuleKind` avec son nom, son symbole SF Symbols et sa page.
2. S'il a une logique calculable (durées, règles), l'écrire dans `NotchitCore` avec un test.
3. Créer son modèle (`Sources/Notchit/MonModuleModel.swift`), un `ObservableObject` qui ne travaille que si le module est actif.
4. Créer sa vue (dans `Cards.swift` ou un nouveau fichier) et l'ajouter dans `agenda(...)`, `files(...)` ou `MediaPage` de `NotchView.swift`.
5. L'injecter dans `NotchController.show()` avec `.environmentObject(...)`.
6. S'il demande une autorisation macOS : texte d'explication dans `build.sh` (Info.plist), droit dans `Resources/Notchit.entitlements`, ligne dans l'onglet Confidentialité et dans `SECURITY.md`.

## 6. Changer l'apparence

- Thèmes : `Sources/NotchitCore/Theme.swift`. Un thème doit garder un contraste lisible ; le test `testPresetsAreReadable` le vérifie.
- Marges : toujours le même retrait en bas que sur les côtés (`bottomInset` dans `NotchView.swift`), 16 points entre deux cartes, 12 sous la ligne des onglets. La ligne du haut reste dans les deux « oreilles » de part et d'autre de l'encoche matérielle (`ear` dans `NotchView.swift`) : rien ne doit passer sous la caméra. Vérifier à la plus petite taille d'encoche, pas seulement à la taille par défaut.
- Orange du minuteur : `TimerStyle.orange` dans `Cards.swift`.
- Icône : modifier `Tools/make-icon.swift`, puis :

```
swift Tools/make-icon.swift /tmp/AppIcon.iconset
iconutil -c icns /tmp/AppIcon.iconset -o Resources/AppIcon.icns
```

## 7. Sortir une version

1. Changer `VERSION` et `BUILD` en haut de `build.sh`.
2. `swift test`, puis `./build.sh`, puis tester à la main chaque page, à la taille la plus petite et la plus grande.
3. Pour distribuer à d'autres personnes, il faut un compte développeur Apple payant : signer avec un certificat « Developer ID Application », puis faire notariser l'application (`xcrun notarytool submit`) et l'agrafer (`xcrun stapler staple`). Sans cela, macOS bloque l'ouverture chez les autres.
4. Mettre à jour le README (nouveautés) et `SECURITY.md` si une autorisation a changé.

## 8. Lien de soutien

L'adresse de dons est à un seul endroit : `Links.support` dans `Sources/Notchit/NotchitApp.swift` (entrée « Soutenir Notchit… » du menu), plus `.github/FUNDING.yml` (bouton « Sponsor » de GitHub) et la section « Soutenir le projet » du README. Mettre `Links.support` à `nil` retire l'entrée du menu.

## 9. Où sont les données

Tout est dans les préférences de `fr.livio-studio.notchit` (`defaults read fr.livio-studio.notchit`) :
- `settings.v1` : les réglages, en JSON ; exportables et importables depuis l'onglet Sauvegarde ;
- `shelf.paths` : les chemins des fichiers de l'étagère (les fichiers eux-mêmes ne sont ni copiés ni déplacés) ;
- `timer.v1` : le minuteur, le chrono ou le Pomodoro en cours.

Tout effacer : `defaults delete fr.livio-studio.notchit`, Notchit fermé.
