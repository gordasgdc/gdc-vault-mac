#!/usr/bin/env bash
# Builds "GDC Vault.app" fresh (fara instalare directa in /Applications,
# vezi build_app.sh pentru asta), apoi il impacheteaza intr-un .pkg
# semnat + notarizat, cu panou de licenta (Terms & Conditions).
#
# NOTE: produce un .pkg SEMNAT + NOTARIZAT automat daca certificatele
# Developer ID Application/Installer sunt configurate (vezi
# codesigning/README.md). Altfel cade pe un pachet NESEMNAT.
set -euo pipefail
cd "$(dirname "$0")"

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist)
PKG_ID="com.gordasgdc.vault.installer"
APP_NAME="GDC Vault.app"
DIST_DIR="dist"
PAYLOAD_ROOT="$DIST_DIR/payload"
COMPONENT_PKG="$DIST_DIR/GDCVault-component.pkg"
FINAL_PKG="$DIST_DIR/GDCVault-$VERSION.pkg"

echo "==> Building app…"
swift build -c release --product GDCVault
BUILD_OUT="/tmp/GDC Vault.app.build-$$"
rm -rf "$BUILD_OUT"
mkdir -p "$BUILD_OUT/Contents/MacOS" "$BUILD_OUT/Contents/Resources"
cp .build/release/GDCVault "$BUILD_OUT/Contents/MacOS/GDCVault"
cp Info.plist "$BUILD_OUT/Contents/Info.plist"
cp AppIcon.icns "$BUILD_OUT/Contents/Resources/AppIcon.icns"
# Ghidul PDF accesibil DIN aplicatie (Setari + meniul Help), nu doar in
# arhiva - vezi build_app.sh si SettingsView.swift (2026-08-27).
if [ -f "installer/Instructiuni_Utilizare.pdf" ]; then
    cp "installer/Instructiuni_Utilizare.pdf" "$BUILD_OUT/Contents/Resources/"
fi

if [ -n "${APPLE_SIGN_IDENTITY_APP:-}" ]; then
    ./codesigning/sign-and-notarize.sh app "$BUILD_OUT"
else
    echo "AVERTISMENT: APPLE_SIGN_IDENTITY_APP nesetat - semnez ad-hoc (pachetul final va ramane nesemnat)."
    codesign --force --deep --sign - "$BUILD_OUT"
fi

rm -rf "$DIST_DIR"
mkdir -p "$PAYLOAD_ROOT/Applications"
cp -R "$BUILD_OUT" "$PAYLOAD_ROOT/Applications/$APP_NAME"
rm -rf "$BUILD_OUT"

echo "==> Building component package…"
# --scripts: preinstall CURATA doar o instalare veche ramasa (pkill +
# rm -rf /Applications/"GDC Vault.app"), ca sa nu ramana doua copii ale
# aplicatiei cu acelasi bundle ID pe disc. NU contine niciun hack de
# Gatekeeper/quarantine - pachetul e semnat + notarizat + stapled mai jos,
# deci Gatekeeper il accepta nativ.
pkgbuild \
    --root "$PAYLOAD_ROOT" \
    --identifier "$PKG_ID" \
    --version "$VERSION" \
    --install-location "/" \
    --scripts "installer/scripts" \
    "$COMPONENT_PKG"

echo "==> Writing distribution definition…"
cat > "$DIST_DIR/Distribution.xml" << EOF
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="1">
    <title>GDC Vault $VERSION</title>
    <license file="License.txt" mime-type="text/plain"/>
    <options customize="never" require-scripts="false" rootVolumeOnly="true"/>
    <domains enable_localSystem="true"/>
    <choices-outline>
        <line choice="default">
            <line choice="$PKG_ID"/>
        </line>
    </choices-outline>
    <choice id="default"/>
    <choice id="$PKG_ID" visible="false">
        <pkg-ref id="$PKG_ID"/>
    </choice>
    <pkg-ref id="$PKG_ID" version="$VERSION" onConclusion="none">GDCVault-component.pkg</pkg-ref>
</installer-gui-script>
EOF

cp installer/License.txt "$DIST_DIR/License.txt"

echo "==> Building final installer package…"
productbuild \
    --distribution "$DIST_DIR/Distribution.xml" \
    --package-path "$DIST_DIR" \
    --resources "$DIST_DIR" \
    "$FINAL_PKG"

rm -rf "$PAYLOAD_ROOT" "$COMPONENT_PKG"

# Semnare + notarizare a .pkg-ului final, daca certificatul Installer e
# configurat - altfel ramane nesemnat.
./codesigning/sign-and-notarize.sh pkg "$FINAL_PKG"

# Copie cu nume stabil - site-ul/update.json-ul pot trimite mereu la
# releases/latest/download/GDCVault.pkg, fara editare la fiecare release.
cp "$FINAL_PKG" "$DIST_DIR/GDCVault.pkg"

echo "==> Copying uninstaller (Dezinstalare_GDCVault.command)…"
cp "Dezinstalare_GDCVault.command" "$DIST_DIR/Dezinstalare_GDCVault.command"
chmod +x "$DIST_DIR/Dezinstalare_GDCVault.command"

# Bundle .pkg + uninstaller + instructiuni intr-un zip curat. Pachetul e
# semnat + notarizat + stapled, deci Gatekeeper il accepta nativ la
# dublu-click - NU exista niciun launcher/script de bypass. Totul la
# radacina arhivei, fara subfoldere - doar 3 fisiere, fara ambiguitate.
echo "==> Building GDCVault-Mac.zip (pkg + uninstaller + instructiuni)…"
ZIP_STAGE="$DIST_DIR/zip_stage"
rm -rf "$ZIP_STAGE"
mkdir -p "$ZIP_STAGE"
cp "$DIST_DIR/GDCVault.pkg" "$ZIP_STAGE/"
cp "installer/Instructiuni_Utilizare.pdf" "$ZIP_STAGE/" 2>/dev/null || true
cp "$DIST_DIR/Dezinstalare_GDCVault.command" "$ZIP_STAGE/"
chmod +x "$ZIP_STAGE/Dezinstalare_GDCVault.command"
( cd "$ZIP_STAGE" && zip -q -r -y "../GDCVault-Mac.zip" . )
rm -rf "$ZIP_STAGE"

echo "==> Done: $FINAL_PKG"
echo "==> Also: $DIST_DIR/GDCVault.pkg, $DIST_DIR/Dezinstalare_GDCVault.command, $DIST_DIR/GDCVault-Mac.zip"
echo "    Upload GDCVault-Mac.zip to the GitHub release (that's what the website links to)."
