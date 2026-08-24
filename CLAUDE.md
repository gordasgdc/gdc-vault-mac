# GDC Vault (Mac) — note de arhitectură

Aplicație standalone GDC: gestionare centralizată de licențe/abonamente/credențiale
pentru creatori de conținut și editori video. ID produs oficial: `gdc-vault`.

## Arhitectura fișei de produs (rescrisă 2026-08-24)

Prima versiune avea `VaultEntryKind` (licență / abonament / credential) ca
selector EXCLUSIV — Cristi a oprit testarea aici: un produs real (Adobe,
Motion Array) are simultan cont de login ȘI cheie de serie ȘI expirare.
**O intrare = un produs**, cu credențiale + licențiere + resurse pe
ACEEAȘI fișă, simultan. `VaultEntry` nu mai are `kind`; are `licenseType`
(`.none`/`.perpetual`/`.subscription`, informativ, NU exclude celelalte
câmpuri), `hasPassword` și `hasSerial` (DOUĂ sloturi independente în
Keychain — vezi `VaultKeychainStore.SecretSlot`). UI: `NavigationSplitView`
cu sidebar stânga (butoane `Adaugă`/`Export`/`Import` vizibile direct,
NU într-un meniu) + fișa completă în panoul de detaliu (nu sheet modal) —
vezi `ContentView.swift` / `EntryDetailView.swift`.

## Structură

- `Sources/GDCVaultCore/` — model + criptografie, fără UI:
  - `LicenseCore.swift` / `MachineID.swift` — copiate BYTE-FOR-BYTE din
    `gdc-plugin-manager-catalog-vendor/Sources/GDCPluginManagerCore/`. Aceeași
    cheie publică Ed25519 — orice cod generat din Furnizor pentru `gdc-vault`
    funcționează aici neschimbat. **Dacă cheia publică se schimbă vreodată în
    GDCPluginManagerCore, actualizeaz-o și aici manual — nu există dependency
    SPM între repo-uri, e copy-paste intenționat (fiecare app standalone GDC
    face la fel — vezi `gdcStandaloneProducts` din `GenerateSerialView.swift`).**
  - `VaultEntry.swift` — modelul unei intrări (licență/abonament/credential).
    NU conține niciun secret în clar — doar `hasSecret: Bool`.
  - `VaultKeychainStore.swift` — parole/serii în Keychain nativ
    (`kSecClassGenericPassword`, service `com.gordas.gdcvault`, account =
    `entry.id.uuidString`).
  - `AttachmentStore.swift` — contracte/facturi/screenshot-uri, copiate în
    `~/Library/Application Support/GDC Vault/Attachments/<entryID>/`.
  - `VaultMetadataStore.swift` — persistă `[VaultEntry]` ca JSON simplu în
    `~/Library/Application Support/GDC Vault/entries.json` (fără secrete).
  - `PBKDF2.swift` / `VaultExportImport.swift` — backup/restore criptat
    AES-256-GCM, parolă Master aleasă de utilizator. Vezi secțiunea Export/Import.
- `Sources/GDCVault/` — UI SwiftUI (listă, editor unic pe tip, banner expirare,
  export/import).
- `uninstall.sh` — dezinstalare completă (vezi Regula de Clean Uninstall).

## Export / Import (backup criptat, portabil Mac ⇄ Windows)

Format fișier `.gdcvault`, IDENTIC pe Mac și Windows (vezi oglinda C#,
`gdc-vault-win/src/GDCVault.Core/Services/VaultExportImport.cs`):

```
[8 bytes magic "GDCVLT1\0"][16 bytes salt][AES-GCM combined: 12B nonce + ciphertext + 16B tag]
```

Plaintext-ul criptat e un JSON cu toate intrările, secretele lor (citite din
Keychain doar cât durează operația) și atașamentele ca base64 inline. Cheia
se derivă din parola Master prin PBKDF2-HMAC-SHA256, 200k iterații, 32 bytes —
**acești parametri trebuie să rămână identici între Swift și C#**, altfel un
backup exportat pe o platformă nu se mai importă pe cealaltă. O parolă greșită
la import face ca `AES.GCM.open` să arunce (tag-ul de autentificare GCM nu se
potrivește) — nu descifrează date corupte, eroarea e clară.

## Regula de Clean Uninstall (permanentă, tot ecosistemul GDC)

Vezi `gdc-plugin-manager-catalog-vendor/CLAUDE.md` pentru regula completă.
Aici: `uninstall.sh` șterge `.app`-ul, `~/Library/Application Support/GDC Vault`,
`~/Library/Caches/com.gordas.gdcvault`, `~/Library/Preferences/com.gordas.gdcvault.plist`,
`~/Library/Logs/GDC Vault`, și TOATE item-urile Keychain cu service
`com.gordas.gdcvault` (șterse în buclă — un singur apel de
`security delete-generic-password` șterge un singur item, nu toate).
**Dacă adaugi vreodată o setare persistentă nouă (UserDefaults, cache,
fișier), adaug-o și în `uninstall.sh` în ACELAȘI commit.**

## Iconiță (`AppIcon.icns` / favicon)

Generată programatic (Pillow, `/tmp/gen_vault_icon.py` — nu e comisă, doar
rezultatul): seif stilizat (cerc dublu + gaură de cheie), ardezie închisă
(`#1e293b`→`#0a0e17`) cu accent neon cyan/violet, în stilul deja consacrat
în ecosistemul GDC. Master la 1024×1024 în `Assets/icon-1024-master.png`.
`AppIcon.iconset/` + `AppIcon.icns` generate din el via `sips`/`iconutil`
(exact tiparul din `gdc-plugin-manager-catalog-vendor`). Favicon-uri web
(`.ico`/.png la 16/32px, aceeași convenție ca `docs/index.html` din
catalog-vendor) în `Assets/web/`. **Dacă iconița se redesenează vreodată,
regenerează din același script și rulează din nou `sips`+`iconutil` — nu
edita direct `.icns`.**

## Rebuild local

```bash
cd ~/Downloads/gdc-vault-mac && bash build_app.sh
```

Compilează release, împachetează `GDC Vault.app` (cu `AppIcon.icns`),
semnează cu certificatul local `CursorPro` și instalează în
`/Applications/GDC Vault.app` — exact tiparul din `build_app.sh` al
`GDCPluginManager`, minus bundle-ul Python (nefolosit aici).

## CI/CD (2026-08-24)

Repo-uri publice pe GitHub: `gordasgdc/gdc-vault-mac` + `gordasgdc/gdc-vault-win`.
`.github/workflows/build-mac.yml` — ruleaza pe `macos-latest` la orice push pe
`main`. **NU reutilizeaza `build_app.sh`** (acela instaleaza direct in
`/Applications` si semneaza cu certificatul local `CursorPro` al lui Cristi,
inexistent pe runner) — impacheteaza manual, semnare ad-hoc (`--sign -`),
doar artefact descarcabil + verificare independenta de mediu.

## Licențiere (2026-08-24)

Probă 15 zile + Lifetime 5€ (preț promoțional beta) — `LicenseManager.swift`,
port 1:1 al celui din DataMover (`productID = "gdc-vault"`,
`trialDurationDays = 15`). Activare: buton WhatsApp (`WhatsAppLink.swift`,
mesaj prefilled cu ID-ul mașinii) → Cristi generează codul manual din
Furnizor (`GenerateSerialView.swift`, `gdcStandaloneProducts` include acum
`gdc-vault`) → codul se introduce în `ActivationSheet.swift`.

**Decizie de produs, importantă**: spre deosebire de DataMover (unde
`isUnlocked` blochează "Start"), la Vault NU se blochează accesul la
intrările deja salvate după expirarea probei — doar `+ Adaugă aplicație`
verifică `license.isUnlocked`. Un "seif" care te încuie afară de propriile
parole ar fi ostil, nu de încredere.

Integrare ecosistem: `gdc-vault` apare acum și în `catalog.json` (categoria
`apps`, cu copertă `docs/covers/gdc-vault.png`) — deci e vizibil în
secțiunea Aplicații din GDC Plugin Manager, cu link către
`gordas.dev/gdc-vault` (pagina de prezentare).
