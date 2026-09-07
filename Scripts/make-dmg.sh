#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Pace.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
DMG="build/Pace-${VERSION}.dmg"

[ -d "$APP" ] || { echo "Build d'abord: Scripts/make-app.sh release"; exit 1; }

STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG"
hdiutil create -volname "Pace" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

echo "→ $DMG"
