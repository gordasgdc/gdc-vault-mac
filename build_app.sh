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

# Acelasi certificat local de incredere folosit pe toate aplicatiile GDC
# din aceasta sesiune - nicio permisiune TCC-gated nu e necesara aici,
# dar o identitate stabila evita frictiunea Gatekeeper "unknown developer"
# la fiecare rebuild.
SIGN_IDENTITY="CursorPro"
codesign --force --deep --sign "$SIGN_IDENTITY" "$BUILD_OUT"

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
