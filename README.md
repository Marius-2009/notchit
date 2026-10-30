# Notchit

Notchit transforme l'encoche du MacBook en petit centre de contrôle, dans l'esprit de la Dynamic Island de l'iPhone. Fait par Marius Morelli-Vidal, pour lui, en open source.

Documentation :
- [GUIDE.md](GUIDE.md) : comment c'est construit, comment modifier, ajouter ou retirer une fonctionnalité, comment sortir une version.
- [AGENTS.md](AGENTS.md) : instructions pour les assistants de code IA (Claude Code, Codex, Cursor...).
- [SECURITY.md](SECURITY.md) : autorisations, données enregistrées, vie privée.

Chaque module se coupe dans Réglages > Modules ; le guide explique comment le retirer du code.

## Installer

1. Téléchargez `Notchit.zip` dans la dernière version publiée (onglet Releases), puis ouvrez-le.
2. Glissez `Notchit.app` dans le dossier Applications.
3. Notchit n'est pas encore vérifié par Apple (cela coûte 99 $ par an) : au premier lancement, macOS refuse de l'ouvrir. C'est normal, le code est entièrement lisible ici.
   - macOS 15 et plus récent : double-cliquez une première fois sur Notchit, fermez le message, puis ouvrez Réglages Système > Confidentialité et sécurité, descendez jusqu'à « Notchit a été bloqué » et cliquez sur « Ouvrir quand même », puis confirmez.
   - macOS 14 : clic droit sur Notchit > Ouvrir, puis Ouvrir.
4. Notchit apparaît dans l'encoche. La roue crantée en haut à droite de l'encoche ouvre les réglages.

Il faut macOS 14 ou plus récent. Sans encoche (écran externe, ancien Mac), Notchit en dessine une.

Pour le construire soi-même à partir du code : voir [GUIDE.md](GUIDE.md).

## Soutenir le projet

Notchit est gratuit, sans publicité et sans collecte de données. Si vous l'aimez et voulez aider à le faire durer, vous pouvez soutenir le projet sur [GitHub Sponsors](https://github.com/sponsors/Marius-2009), ou depuis le menu de l'application (« Soutenir Notchit… »). C'est facultatif : rien n'est bloqué sans don.

## Version 0.6

- Taille de l'encoche bornée à 440 × 180 minimum et 760 × 300 maximum, pour que tout reste lisible.
- Minuteur en trois modes : minuteur à roues, Pomodoro (durées, nombre de sessions et enchaînement réglables, bouton « Passer ») et chronomètre.
- Le minuteur, le Pomodoro ou le chrono en cours survit au redémarrage de Notchit.
- Roue des minutes jusqu'à 99 quand la roue des heures n'a pas la place.
- Onglet Confidentialité : couper la lecture système, accès direct aux autorisations macOS, effacement des données.
- Lancement à l'ouverture de session (Réglages > Comportement).
- Signature avec le runtime durci et les seuls droits nécessaires ; pochettes Spotify en HTTPS uniquement.
- Icône d'application.

## Version 0.5

- Trois pages : Musique, Agenda (calendrier et minuteur), Fichiers et miroir (étagère et miroir). Onglets en haut à gauche ou balayage à deux doigts.
- Étagère avec de vraies vignettes (Quick Look) et le nom du fichier ; un clic ouvre l'aperçu en grand dans l'encoche (dimensions, précédent, suivant, ouvrir), un double-clic ouvre le fichier.
- Minuteur réglé par des roues heures, minutes, secondes (minutes et secondes quand la place manque) : défilement au trackpad ou à la molette, clic sur un chiffre ; la roue reprend la dernière durée lancée.

## Version 0.4

- Deux pages dans l'encoche ouverte, Média et Outils : onglets en haut à gauche, ou balayage à deux doigts sur le trackpad.
- Média : tout ce qui joue sur le Mac, Spotify, Musique, et les vidéos ou sons d'un navigateur (Chrome, Safari, Arc, Firefox...), avec pochette, appli source, position réglable au doigt, lecture, pause, précédent, suivant.
- Minuteur dans le style de la Dynamic Island : orange, anneau de progression autour de la pause, chiffres qui défilent, décompte orange dans l'encoche fermée.
- Miroir réparé : il prend la caméra du Mac, pas une caméra virtuelle (OBS), et ne plante plus au démarrage.
- Mise en page adaptée à la taille de l'encoche : rien ne déborde, le minuteur passe en anneau compact quand la place manque, le miroir prend toute la page Outils quand il est allumé.
- Calendrier : un événement présent dans deux agendas ne s'affiche qu'une fois ; la liste s'adapte à la hauteur.

## Version 0.3

- Calendrier : prochains événements d'aujourd'hui et de demain, lus dans les agendas du Mac (EventKit) après votre accord, couleur de l'agenda, « dans 12 min », « en cours ».
- Minuteur : durées rapides réglables (5, 15 et 25 min par défaut), pause, +1 min, arrêt ; le décompte reste visible dans l'encoche fermée, son et ouverture brève à la fin.
- Miroir : la caméra s'allume seulement au clic et s'éteint dès que l'encoche se ferme. Rien n'est enregistré.
- Les modules du milieu se rangent côte à côte, l'étagère passe en bande en bas.

## Version 0.2

- Encoche qui s'ouvre au survol (délais d'ouverture et de fermeture réglables, marge de la zone de survol), d'un clic sur l'encoche, ou au clavier (⌥⌘N par défaut, modifiable).
- Mode édition : poignées pour redimensionner l'encoche ouverte à la souris, taille affichée en direct, retour à la taille d'origine.
- Réglages complets dans une vraie fenêtre (menu de la barre, « Réglages… ») : comportement, taille et arrondis, animations, apparence, modules, raccourci, sauvegarde.
- Thèmes : Noir, Graphite, Minuit, Forêt, Sable, Verre, et un thème personnalisé avec contrôle du contraste.
- Modules à activer et réordonner : batterie, heure et date, lecture en cours, étagère.
- Lecture en cours (Spotify et Musique) : pochette, titre, artiste, progression, lecture, pause, morceau précédent et suivant ; pochette et visualiseur dans l'encoche fermée.
- Étagère : glissez des fichiers sur l'encoche, reprenez-les en les glissant ailleurs.
- Réglages enregistrés entre les lancements, exportables et importables en JSON, réinitialisables.

## Limites connues

- Retour haptique : macOS ne fait vibrer que les trackpads Force Touch, et seulement quand un doigt est posé dessus. Sans effet à la souris.
- L'encoche fermée reste noire quel que soit le thème, pour se fondre avec celle de l'écran.
- Sans encoche (écran externe, ancien Mac), Notchit dessine une encoche virtuelle en haut au centre de l'écran principal.
- Lecture en cours : macOS réserve l'accès système (MediaRemote) à ses propres programmes depuis la version 15.4. Notchit le lit par un petit module chargé dans `/usr/bin/perl`, programme signé par Apple, comme d'autres applications d'encoche. Si Apple ferme cette porte, Notchit revient à AppleScript (Spotify et Musique seulement).
- Signée avec le certificat Apple Development s'il existe sur le Mac, pour que les autorisations caméra et calendrier tiennent d'une construction à l'autre ; sinon signature ad hoc, et macOS redemande.
- Avec tous les modules du milieu actifs, il faut au moins 680 points de large.

## Construire

Il faut macOS 14 ou plus récent et les outils Xcode.

```
./build.sh
open build/Notchit.app
```

Tests : `swift test`.

Arguments de lancement utiles pour tester : `open build/Notchit.app --args --reglages --edition`.

## Organisation

- `Sources/NotchitCore` : réglages, thèmes, raccourci et géométrie, sans interface, couverts par les tests.
- `Sources/Notchit` : l'application (fenêtre de l'encoche, vues, réglages, raccourci global, modules).
- `Tests/NotchitCoreTests` : tests unitaires.

## Licence

MIT, voir `LICENSE`.
