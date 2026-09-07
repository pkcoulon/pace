#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

TMP="$(mktemp -d)/Pace.iconset"
mkdir -p "$TMP"
swift Scripts/generate-icon.swift "$TMP"
iconutil -c icns "$TMP" -o Resources/Pace.icns
rm -rf "$(dirname "$TMP")"
echo "→ Resources/Pace.icns"
