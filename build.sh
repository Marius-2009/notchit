#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
VERSION=0.6.0
BUILD=6
swift build -c release
APP=build/Notchit.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Notchit "$APP/Contents/MacOS/Notchit"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
bridge() { clang ${1:+-isysroot "$1"} -dynamiclib -fobjc-arc -O2 -mmacosx-version-min=14.0 -framework AppKit Helper/MediaBridge.m -o "$APP/Contents/Resources/MediaBridge.dylib" 2>/dev/null; }
if ! bridge; then
  for sdk in $(ls -dr /Library/Developer/CommandLineTools/SDKs/MacOSX[0-9]*.sdk 2>/dev/null); do bridge "$sdk" && break; done
fi
[ -f "$APP/Contents/Resources/MediaBridge.dylib" ] || { echo "MediaBridge.dylib : compilation impossible" >&2; exit 1; }
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Notchit</string>
  <key>CFBundleDisplayName</key><string>Notchit</string>
  <key>CFBundleIdentifier</key><string>fr.livio-studio.notchit</string>
  <key>CFBundleExecutable</key><string>Notchit</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSCameraUsageDescription</key><string>Notchit allume la caméra seulement quand vous cliquez sur le miroir, et l'éteint à la fermeture de l'encoche. Rien n'est enregistré.</string>
  <key>NSCalendarsFullAccessUsageDescription</key><string>Notchit affiche vos prochains événements dans l'encoche. Rien ne quitte votre Mac.</string>
  <key>NSCalendarsUsageDescription</key><string>Notchit affiche vos prochains événements dans l'encoche. Rien ne quitte votre Mac.</string>
  <key>NSAppleEventsUsageDescription</key><string>Notchit lit le morceau en cours dans Spotify et Musique pour l'afficher dans l'encoche.</string>
</dict>
</plist>
PLIST
ID=$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/ {print $2; exit}')
codesign --force --sign "${ID:--}" --options runtime --timestamp=none "$APP/Contents/Resources/MediaBridge.dylib"
codesign --force --sign "${ID:--}" --options runtime --timestamp=none --entitlements Resources/Notchit.entitlements "$APP"
codesign --verify --strict "$APP"
echo "$APP"
