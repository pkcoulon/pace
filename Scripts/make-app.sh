#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
APP="build/UsageBar.app"

swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/UsageBar"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/UsageBar"
cp Resources/Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Signature : identité stable via SIGN_IDENTITY (empreinte ou nom du certificat),
# sinon signature ad hoc. Une identité stable évite que macOS redemande les
# autorisations (Trousseau, notifications) à chaque rebuild.
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
codesign --force --sign "$SIGN_IDENTITY" "$APP"

echo "→ $APP (signé: $SIGN_IDENTITY)"
