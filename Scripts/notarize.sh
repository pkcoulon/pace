#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

# Signe (hardened runtime), construit le .dmg, le notarise chez Apple et l'agrafe.
#
# Prérequis, une seule fois :
#   1) Un certificat "Developer ID Application" dans ton Trousseau, créé sur
#      https://developer.apple.com/account/resources/certificates
#   2) Un profil notarytool enregistré avec un mot de passe d'app dédié :
#        xcrun notarytool store-credentials pace-notary \
#          --apple-id "<ton-apple-id>" --team-id "<TON_TEAM_ID>" \
#          --password "<mot-de-passe-app-spécifique>"
#
# Puis :
#   SIGN_IDENTITY="Developer ID Application: <Ton Nom> (<TON_TEAM_ID>)" \
#     NOTARY_PROFILE=pace-notary Scripts/notarize.sh

: "${SIGN_IDENTITY:?Définis SIGN_IDENTITY sur ton Developer ID Application}"
NOTARY_PROFILE="${NOTARY_PROFILE:-pace-notary}"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
DMG="build/Pace-${VERSION}.dmg"

SIGN_IDENTITY="$SIGN_IDENTITY" Scripts/make-app.sh release
Scripts/make-dmg.sh
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
echo "→ $DMG notarisé et agrafé"
