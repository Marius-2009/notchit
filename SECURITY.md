# Sécurité et vie privée

## Principes

- Aucune donnée ne quitte le Mac. Pas de compte, pas de télémétrie, pas de statistiques d'usage, pas de serveur.
- Une seule requête réseau : la pochette du morceau Spotify, téléchargée en HTTPS depuis les serveurs de Spotify (moins de 5 Mo, uniquement depuis les serveurs d'images de Spotify en HTTPS), et seulement quand le module média système est désactivé ou indisponible.
- Chaque fonction qui touche à quelque chose de personnel se coupe dans Réglages > Modules, et chaque autorisation se retire dans Réglages Système > Confidentialité et sécurité.

## Autorisations demandées

| Autorisation | Pour quoi | Quand |
|---|---|---|
| Caméra | le miroir | au premier clic sur le miroir ; la caméra s'allume seulement après un clic, s'éteint quand on recoupe ou quand l'encoche se ferme ; aucune image n'est enregistrée |
| Calendriers | afficher les prochains événements | au clic sur « Autoriser » dans la carte calendrier ; lecture seule |
| Automatisation (Spotify, Musique) | lire et piloter la musique quand le module système est coupé ou indisponible | au premier morceau |

Droits de signature (`Resources/Notchit.entitlements`) : `device.camera`, `personal-information.calendars`, `automation.apple-events`, rien d'autre. L'application est signée avec le runtime durci (`--options runtime`).

## Le module « lecture système »

Depuis macOS 15.4, Apple réserve l'accès à « ce qui joue sur le Mac » (framework privé MediaRemote) à ses propres programmes. Notchit compile un petit module (`Helper/MediaBridge.m`, une centaine de lignes, lisible) et le fait exécuter par `/usr/bin/perl`, programme signé par Apple, dans un processus séparé. Ce module :
- lit le titre, l'artiste, l'album, la durée, la position, la pochette et l'application qui joue ;
- reçoit seulement quatre commandes : lecture/pause, suivant, précédent, aller à une position ;
- n'ouvre aucune connexion réseau et n'écrit aucun fichier ;
- s'arrête tout seul quand Notchit se ferme.

Il utilise une interface privée d'Apple : cela fonctionne aujourd'hui, mais une mise à jour de macOS peut le casser. Notchit revient alors à AppleScript (Spotify et Musique uniquement). On peut le couper à tout moment : Réglages > Confidentialité > « Lire ce qui joue dans tout le système ».

## Données enregistrées

Dans les préférences de `fr.livio-studio.notchit`, sur ce Mac uniquement :
- réglages (`settings.v1`), validés et bornés à chaque lecture, y compris à l'import d'un fichier ;
- chemins des fichiers de l'étagère (`shelf.paths`), pas les fichiers ; les fichiers disparus sont ignorés au lancement ;
- état du minuteur (`timer.v1`).

Effacement : Réglages > Confidentialité > « Vider l'étagère et le minuteur », ou `defaults delete fr.livio-studio.notchit` pour tout.

Les journaux ne contiennent ni titres, ni noms de fichiers, ni événements d'agenda.

## Signaler un problème

Écrire à Marius Morelli-Vidal (Livio Studio) en privé plutôt que dans un ticket public, avec la version (menu de la barre, ou `CFBundleShortVersionString`) et les étapes pour reproduire.
