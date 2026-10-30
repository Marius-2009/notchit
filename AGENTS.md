# AGENTS.md : instructions pour les agents IA

Fichier lu par les assistants de code (Claude Code, Codex, Cursor, Copilot...). Le guide humain complet est `GUIDE.md` ; la politique de sécurité est `SECURITY.md`. Lis les trois avant une modification non triviale.

## Projet

Notchit : application macOS (Swift 5.9, SwiftUI + AppKit, macOS 14 minimum) qui transforme l'encoche du MacBook en panneau à trois pages : Musique, Agenda (calendrier, minuteur, Pomodoro, chrono), Fichiers et miroir (étagère, caméra). Application de barre des menus (`LSUIElement`), sans Dock, sans bac à sable, signée avec le runtime durci.

Langue : interface, textes, commentaires de commit et documentation en français, avec accents. Code et identifiants en anglais.

## Commandes

```
swift build                 compile (rapide, à lancer après chaque modification)
swift test                  tests de NotchitCore ; doivent rester verts
./build.sh                  construit build/Notchit.app (icône, module média, Info.plist, signature)
open build/Notchit.app      lance ; quitter l'ancienne instance avant (pkill -x Notchit)
open build/Notchit.app --args --reglages --edition    ouvre réglages et mode redimensionnement
```

## Architecture

- `Sources/NotchitCore` : logique pure, sans AppKit ni SwiftUI. `Settings.swift` (réglages `NotchSettings`, bornes, `ModuleKind`, `NotchPage`, géométrie), `Theme.swift`, `Countdown.swift` (`Countdown`, `Stopwatch`, `Pomodoro`, `TimerSnapshot`). Toute règle calculable va ici, avec un test dans `Tests/NotchitCoreTests`.
- `Sources/Notchit` : un modèle `ObservableObject` par module (`MusicModel`, `CalendarModel`, `TimerModel`, `MirrorModel`, `ShelfModel`, `BatteryModel`), injectés par `NotchController.show()` en `environmentObject`. Les vues sont dans `NotchView.swift` (structure, pages Musique et Fichiers, étagère) et `Cards.swift` (Agenda, miroir).
- Réglages : `SettingsStore.value` (`NotchSettings`), sauvegardés en JSON dans UserDefaults (`settings.v1`) à chaque changement, toujours passés par `clamped()`. Un nouveau réglage = une propriété avec valeur par défaut dans `NotchSettings`, une borne dans `clamped()` si numérique, un test. `decode` fusionne avec les valeurs par défaut : ne jamais casser la lecture d'anciens réglages.
- Mise en page : chaque page reçoit sa taille par `GeometryReader` et s'adapte (voir `agenda(...)`, `files(...)`, `MediaPage.layout`, `TimerCard`). L'encoche va de 440 × 180 à 760 × 300 (`widthRange`, `heightRange`) : rien ne doit déborder ni être coupé entre ces bornes.
- Lecture en cours : `Helper/MediaBridge.m` compilé en `MediaBridge.dylib`, chargé par `/usr/bin/perl` (processus séparé), dialogue en lignes JSON sur stdout et commandes texte sur stdin. Repli automatique sur AppleScript (Spotify, Musique). Désactivable (`systemMedia`).

## Règles à respecter

1. Tout module doit rester désactivable dans Réglages > Modules, et supprimable du code : quand tu ajoutes un module, ajoute sa section dans `GUIDE.md` §4 (fichiers et lignes à retirer).
2. Vie privée : aucune donnée ne quitte le Mac. Pas de télémétrie, pas d'analyse, pas de requête réseau sauf la pochette Spotify en HTTPS. La caméra ne s'allume qu'après un clic et s'éteint à la fermeture de l'encoche. Pas de lecture du presse-papiers, du micro ou de l'écran sans action explicite de l'utilisateur et sans réglage dédié. Rien de sensible dans les journaux.
3. Nouvelle autorisation macOS : texte d'explication dans l'Info.plist de `build.sh`, droit dans `Resources/Notchit.entitlements`, ligne dans l'onglet Confidentialité (`SettingsView.swift`) et dans `SECURITY.md`. Ne pas activer le bac à sable sans vérifier le module média et AppleScript.
4. Ne pas ajouter de dépendance externe (Swift Package, CocoaPods) sans demande explicite : tout est fait avec les frameworks d'Apple.
5. Marges : même retrait en bas que sur les côtés (`bottomInset`), 16 points entre cartes, 12 sous les onglets. La ligne du haut (onglets, batterie, heure) tient dans les « oreilles » à gauche et à droite de l'encoche matérielle (`ear`, `notchGap`) : rien sous la caméra. Vérifier visuellement à la plus petite taille et à la taille par défaut, captures à l'appui (`screencapture -x -R x,y,w,h fichier.png`).
6. Threads : l'interface et les `@Published` sur le fil principal. La caméra (`AVCaptureSession`) se configure et démarre sur sa file dédiée ; une session neuve à chaque allumage ; un aperçu (`AVCaptureVideoPreviewLayer`) par vue, détaché à la destruction.
7. Accessibilité : chaque bouton icône a un `accessibilityLabel` en français ; respecter « Réduire les animations » (`settings.animation`).
8. Pas de tiret cadratin dans les textes visibles.
9. Après une modification : `swift build`, `swift test`, `./build.sh`, lancement réel et capture d'écran de la partie touchée. Ne pas déclarer terminé sans l'avoir vu fonctionner.

## Pièges connus

- Un geste « tap » posé sur une ligne à l'intérieur d'un `ScrollView` est avalé par le défilement sur macOS : utiliser `simultaneousGesture(SpatialTapGesture)` sur le conteneur (voir `WheelColumn`).
- Une mise à jour des Command Line Tools peut casser l'édition de liens de clang avec le nouveau SDK : `build.sh` essaie alors les autres SDK installés.
- macOS 15.4 et plus bloque `MediaRemote` pour les applications tierces ; seul le passage par `/usr/bin/perl` fonctionne. Si Apple le ferme, le repli AppleScript doit continuer à marcher.
- Les autorisations (caméra, calendrier) sont liées à la signature : signer toujours avec la même identité, sinon macOS les redemande.
- Le raccourci global passe par Carbon (`RegisterEventHotKey`) : il échoue si une autre application l'a pris, l'utilisateur est alors prévenu.
