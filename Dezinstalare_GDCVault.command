#!/usr/bin/env bash
#
# Dezinstalare_GDCVault.command
# Dezinstalare & curatare completa pentru GDC Vault.
#
# Ce face:
#   1. Opreste fortat orice instanta ramasa in fundal.
#   2. Sterge aplicatia + toate fisierele de date/preferinte/cache asociate.
#   3. Sterge toate secretele (parole/chei de serie) din Keychain.
#
# Bundle ID real: com.gordasgdc.vault (Info.plist). Service Keychain:
# com.gordas.gdcvault (VaultKeychainStore.swift).
#
# Rulare: dublu-click, sau click-dreapta -> Open (Terminal), sau din terminal:
#   chmod +x Dezinstalare_GDCVault.command && ./Dezinstalare_GDCVault.command
#
# NOTA 1: daca fisierul a fost descarcat separat (nu din arhiva .zip
# originala), poate avea flag-ul de quarantine si/sau bitul de executie
# lipsa - ruleaza intai:
#   xattr -d com.apple.quarantine Dezinstalare_GDCVault.command
#   chmod +x Dezinstalare_GDCVault.command
#
# NOTA 2: stergerea /Applications/"GDC Vault.app" poate cere parola de
# administrator (sudo), in functie de cum a fost instalata - scriptul
# cere sudo DOAR daca stergerea normala esueaza, nu de la inceput.

set -uo pipefail

BUNDLE_ID="com.gordasgdc.vault"
KEYCHAIN_SERVICE="com.gordas.gdcvault"
APP_PATH="/Applications/GDC Vault.app"

echo "=================================================="
echo " GDC Vault — Dezinstalare & Curatare completa"
echo "=================================================="
echo ""

read -p "Sigur vrei sa stergi GDC Vault si TOATE datele lui (licente, parole, atasamente)? [y/N] " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Anulat."
    exit 0
fi
echo ""

# ---- Pasul 1: Oprire procese -------------------------------------------
echo "[1/3] Opresc orice instanta GDC Vault ramasa in fundal..."
pkill -x "GDCVault" 2>/dev/null
pkill -f "GDC Vault.app" 2>/dev/null
sleep 1
echo "[+] Procese oprite."
echo ""

# ---- Pasul 2: Stergere aplicatie + fisiere -----------------------------
echo "[2/3] Sterg aplicatia si toate fisierele asociate..."

remove_if_exists() {
    local path="$1"
    if [ ! -e "$path" ]; then
        return
    fi
    # Incearca fara sudo intai - doar daca esueaza real (verificat prin
    # [ -e ] dupa), reincearca cu sudo. Fara verificarea existentei dupa
    # `rm`, un esec pe /Applications (app instalata prin .pkg, owned de
    # root) ar fi raportat gresit ca succes.
    if rm -rf "$path" 2>/dev/null && [ ! -e "$path" ]; then
        echo "      - sters: $path"
        return
    fi
    echo "      - necesita permisiuni de administrator: $path"
    if sudo rm -rf "$path" && [ ! -e "$path" ]; then
        echo "      - sters (cu sudo): $path"
    else
        echo "      - EROARE: nu am putut sterge $path"
    fi
}

remove_if_exists "$APP_PATH"
remove_if_exists "$HOME/Library/Application Support/GDC Vault"
remove_if_exists "$HOME/Library/Caches/$BUNDLE_ID"
defaults delete "$BUNDLE_ID" 2>/dev/null || true
remove_if_exists "$HOME/Library/Preferences/$BUNDLE_ID.plist"
remove_if_exists "$HOME/Library/Logs/GDC Vault"
remove_if_exists "$HOME/Library/Saved Application State/$BUNDLE_ID.savedState"

echo "[+] Fisiere sterse."
echo ""

# ---- Pasul 3: Stergere secrete din Keychain -----------------------------
# `security delete-generic-password` sterge UN SINGUR item care se
# potriveste, nu toate - de-aia il rulam in bucla pana nu mai gaseste
# nimic, in loc de un singur apel (care ar lasa orfane toate item-urile
# in afara de primul).
echo "[3/3] Sterg secretele (parole/chei de serie) din Keychain..."
removed=0
while security delete-generic-password -s "$KEYCHAIN_SERVICE" >/dev/null 2>&1; do
    removed=$((removed + 1))
done
echo "[+] Sterse $removed intrari din Keychain (service $KEYCHAIN_SERVICE)"

echo ""
echo "=================================================="
echo " [+] Curatare completa finalizata cu succes!"
echo " Poti reinstala GDC Vault de la zero acum."
echo "=================================================="
echo ""
read -p "Apasa Enter pentru a inchide fereastra..."
