#!/usr/bin/env bash
# Signs, notarizes and staples the macOS export for distribution outside the App Store (Steam).
#   bash tools/release_macos.sh
# Needs: "Developer ID Application" identity in the login keychain and ~/.appstoreconnect/env.sh.
set -euo pipefail
cd "$(dirname "$0")/.."
ID="Developer ID Application: Michel Nguyen (CJ8V64FATZ)"
GODOT="/Applications/Godot 4.7.app/Contents/MacOS/Godot"
source ~/.appstoreconnect/env.sh

"$GODOT" --headless --path . --export-release macOS build/macos/Klanggarten.zip
W="$(mktemp -d)"
ditto -x -k build/macos/Klanggarten.zip "$W"
cat > "$W/ent.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>com.apple.security.device.audio-input</key><true/></dict></plist>
PLIST
APP="$W/Klanggarten.app"
find "$APP/Contents" -type f \( -name "*.dylib" -o -name "*.so" \) -exec codesign --force --timestamp --options runtime -s "$ID" {} \;
codesign --force --deep --timestamp --options runtime --entitlements "$W/ent.plist" -s "$ID" "$APP"
codesign --verify --strict --deep "$APP"
ditto -c -k --keepParent "$APP" "$W/notarize.zip"
xcrun notarytool submit "$W/notarize.zip" --key "$ASC_KEY_FILE" --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER_ID" --wait
xcrun stapler staple "$APP"
spctl --assess --type execute -vv "$APP"
mkdir -p build/macos-signed
ditto -c -k --keepParent "$APP" build/macos-signed/Klanggarten-macOS.zip
echo "Fertig: build/macos-signed/Klanggarten-macOS.zip"
