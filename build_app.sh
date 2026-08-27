#!/usr/bin/env bash
# Builds "GDC Vault.app" din executabilul SPM + Info.plist + AppIcon.icns
# si il instaleaza in /Applications - acelasi tipar ca
# gdc-plugin-manager-catalog-vendor/build_app.sh (fara Python runtime,
# GDC Vault nu are nevoie de el).
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release --product GDCVault

BUILD_OUT="/tmp/GDC Vault.app.build-$$"
rm -rf "$BUILD_OUT"
mkdir -p "$BUILD_OUT/Contents/MacOS"
mkdir -p "$BUILD_OUT/Contents/Resources"

cp .build/release/GDCVault "$BUILD_OUT/Contents/MacOS/GDCVault"
cp Info.plist "$BUILD_OUT/Contents/Info.plist"
cp AppIcon.icns "$BUILD_OUT/Contents/Resources/AppIcon.icns"

# Ghidul PDF trebuie sa fie accesibil DIN aplicatia rulata (Setari > Ghid,
# meniul Help), nu doar in arhiva de instalare - vezi SettingsView.swift
# (2026-08-27, cerinta Cristi: "nu gasesc PDF-ul").
if [ -f "installer/Instructiuni_Utilizare.pdf" ]; then
    cp "installer/Instructiuni_Utilizare.pdf" "$BUILD_OUT/Contents/Resources/"
fi

# Semnare cu Developer ID Application (certificat Apple real) daca e
# configurat - vezi codesigning/README.md - altfel fallback ad-hoc, ca
# rebuild-urile locale de dezvoltare sa functioneze si fara certificat.
if [ -n "${APPLE_SIGN_IDENTITY_APP:-}" ]; then
    ./codesigning/sign-and-notarize.sh app "$BUILD_OUT"
else
    echo "AVERTISMENT: APPLE_SIGN_IDENTITY_APP nesetat - semnez ad-hoc (doar pentru test local)."
    codesign --force --deep --sign - "$BUILD_OUT"
fi

INSTALLED="/Applications/GDC Vault.app"
if [ -d "$INSTALLED" ]; then
    pkill -x GDCVault 2>/dev/null || true
    sleep 0.5
fi
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"$LSREGISTER" -u "$INSTALLED" 2>/dev/null || true
if [ -e "$INSTALLED" ] && [ ! -O "$INSTALLED" ]; then
    sudo rm -rf "$INSTALLED"
    sudo mv "$BUILD_OUT" "$INSTALLED"
    sudo chown -R "$(id -u):$(id -g)" "$INSTALLED"
else
    rm -rf "$INSTALLED"
    mv "$BUILD_OUT" "$INSTALLED"
fi
"$LSREGISTER" -f "$INSTALLED" 2>/dev/null || true
echo "Installed to $INSTALLED"
