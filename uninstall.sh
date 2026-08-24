#!/bin/bash
# GDC Vault — dezinstalare completa (Mac).
#
# REGULA PERMANENTA ecosistem GDC (2026-08-24): orice aplicatie GDC
# (existenta sau noua) trebuie sa vina cu un script de dezinstalare care
# sterge ABSOLUT TOT ce a creat pe sistem — nu doar folderul .app. Un
# uninstall care lasa .plist-uri sau cache-uri orfane e considerat un bug,
# la fel de grav ca un delete-button care nu sterge din catalog.json.
#
# Bundle ID: com.gordasgdc.vault — schimba aici daca-l schimbi in Info.plist.
set -e

BUNDLE_ID="com.gordasgdc.vault"
APP_PATH="/Applications/GDC Vault.app"

echo "GDC Vault — dezinstalare completa"
echo "=================================="

read -p "Sigur vrei sa stergi GDC Vault si TOATE datele lui (licente, parole, atasamente)? [y/N] " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Anulat."
    exit 0
fi

# 1. Aplicatia insasi.
if [ -d "$APP_PATH" ]; then
    rm -rf "$APP_PATH"
    echo "✓ Sters $APP_PATH"
fi

# 2. Datele aplicatiei (entries.json, Attachments/) — vezi
#    VaultMetadataStore.swift / AttachmentStore.swift.
rm -rf "$HOME/Library/Application Support/GDC Vault"
echo "✓ Sters ~/Library/Application Support/GDC Vault"

# 3. Cache-uri (daca vor exista — AsyncImage/URLCache folosesc uneori
#    ~/Library/Caches/<bundle-id>; stergem preventiv, idempotent daca lipseste).
rm -rf "$HOME/Library/Caches/$BUNDLE_ID"
echo "✓ Sters ~/Library/Caches/$BUNDLE_ID"

# 4. Preferinte (UserDefaults -> .plist).
defaults delete "$BUNDLE_ID" 2>/dev/null || true
rm -f "$HOME/Library/Preferences/$BUNDLE_ID.plist"
echo "✓ Sters ~/Library/Preferences/$BUNDLE_ID.plist"

# 5. Loguri.
rm -rf "$HOME/Library/Logs/GDC Vault"
echo "✓ Sters ~/Library/Logs/GDC Vault"

# 6. Secretele din Keychain — VaultKeychainStore.swift scrie un item
#    generic-password per intrare, service "com.gordas.gdcvault". Nu
#    exista un API "sterge toate item-urile cu acest service" fara
#    parola userului la fiecare item individual pe unele versiuni de
#    macOS, deci il tratam separat: security(1) poate sterge in bulk
#    daca userul e logat si Keychain-ul e deblocat.
# `security delete-generic-password` sterge UN SINGUR item care se
# potriveste, nu toate — de-aia il rulam in bucla pana nu mai gaseste
# nimic, in loc de un singur apel (care ar lasa orfane toate item-urile
# in afara de primul).
removed=0
while security delete-generic-password -s "com.gordas.gdcvault" >/dev/null 2>&1; do
    removed=$((removed + 1))
done
echo "✓ Sterse $removed intrari din Keychain (service com.gordas.gdcvault)"

echo ""
echo "GDC Vault a fost dezinstalat complet."
