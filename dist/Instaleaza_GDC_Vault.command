#!/bin/bash
# Instaleaza_GDC_Vault.command
# Wrapper de lansare: (1) muta "GDC Vault.app" in /Applications daca inca
# nu ruleaza de acolo, (2) elimina carantina Gatekeeper si re-semneaza
# ad-hoc, (3) il deschide. Port 1:1 al Instaleaza_DataMover.command din
# repo-ul DataMover — acelasi flux, generalizat pentru GDC Vault.
#
# In arhiva de distributie, "GDC Vault.app" sta intr-un subfolder
# "Aplicatie/" — asta e singurul fisier vizibil in radacina, ca sa nu
# existe confuzie despre pe ce sa apese cineva.

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ -d "${DIR}/Aplicatie/GDC Vault.app" ]; then
    APP_PATH="${DIR}/Aplicatie/GDC Vault.app"
else
    APP_PATH="${DIR}/GDC Vault.app"
fi

if [ ! -d "${APP_PATH}" ]; then
    echo "Eroare: nu am gasit \"GDC Vault.app\" (cautat in Aplicatie/ si in ${DIR})."
    read -p "Apasa Enter pentru a inchide..."
    exit 1
fi

INSTALLED_PATH="/Applications/GDC Vault.app"

if [[ "${APP_PATH}" != "${INSTALLED_PATH}" ]]; then
    echo "==> GDC Vault nu ruleaza din /Applications."
    RESPONSE=$(osascript <<'APPLESCRIPT' 2>/dev/null
button returned of (display dialog "GDC Vault trebuie mutat in folderul Applications ca sa functioneze corect (la fel ca orice aplicatie Mac standard). Il mut acum?" buttons {"Nu acum", "Muta in Applications"} default button "Muta in Applications" with icon note with title "GDC Vault")
APPLESCRIPT
)
    if [[ "${RESPONSE}" == "Muta in Applications" ]]; then
        echo "==> Mut ${APP_PATH} -> ${INSTALLED_PATH}..."
        if [ -d "${INSTALLED_PATH}" ]; then
            rm -rf "${INSTALLED_PATH}" 2>/dev/null
        fi
        if ! ditto "${APP_PATH}" "${INSTALLED_PATH}" 2>/dev/null; then
            echo "==> /Applications necesita privilegii admin — cer confirmare..."
            osascript -e "do shell script \"rm -rf '${INSTALLED_PATH}' 2>/dev/null; ditto '${APP_PATH}' '${INSTALLED_PATH}'\" with administrator privileges" 2>/dev/null
        fi
        if [ -d "${INSTALLED_PATH}" ]; then
            if [ -w "$(dirname "${APP_PATH}")" ]; then
                rm -rf "${APP_PATH}"
            fi
            APP_PATH="${INSTALLED_PATH}"
        else
            echo "AVERTISMENT: mutarea in /Applications a esuat — pornesc din locatia curenta."
        fi
    fi
fi

echo "==> Pregatesc GDC Vault.app pentru lansare..."
xattr -dr com.apple.quarantine "${APP_PATH}" 2>/dev/null
if ! codesign --verify "${APP_PATH}" 2>/dev/null; then
    codesign --force --deep --sign - "${APP_PATH}" 2>/dev/null
fi
open "${APP_PATH}"

echo ""
echo "GDC Vault a pornit. Poti inchide aceasta fereastra."
read -p "Apasa Enter pentru a inchide..."
