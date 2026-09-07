#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
APP="build/Pace.app"

swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/Pace"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Pace"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/Pace.icns "$APP/Contents/Resources/Pace.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Signature : identité stable via SIGN_IDENTITY (empreinte ou nom du certificat),
# sinon signature ad hoc. Une identité stable évite que macOS redemande les
# autorisations (Trousseau, notifications) à chaque rebuild.
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
if [ "$SIGN_IDENTITY" = "-" ]; then
  codesign --force --sign - "$APP"
else
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
fi

echo "→ $APP (signé: $SIGN_IDENTITY)"
