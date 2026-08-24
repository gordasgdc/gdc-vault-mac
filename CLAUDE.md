# GDC Vault (Mac) — note de arhitectură

Aplicație standalone GDC: gestionare centralizată de licențe/abonamente/credențiale
pentru creatori de conținut și editori video. ID produs oficial: `gdc-vault`.

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

## Rebuild local

```bash
cd ~/Downloads/gdc-vault-mac && swift build
```

(Nu există încă `build_app.sh`/instalator — proiectul e la stadiul de scaffold,
rulat direct din `.build/debug/GDCVault` sau din Xcode.)
