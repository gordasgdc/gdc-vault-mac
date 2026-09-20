# GDC Vault (Mac) — note de arhitectură

Aplicație standalone GDC: gestionare centralizată de licențe/abonamente/credențiale
pentru creatori de conținut și editori video. ID produs oficial: `gdc-vault`.

## [PARTEA 1: REGULI GLOBALE ECOSISTEM GDC] — mutată în `~/Developer/CLAUDE.md`

> Din 2026-09-18, regulile globale stau într-un singur fișier,
> `~/Developer/CLAUDE.md`, citit automat de Claude Code în orice proiect din
> `~/Developer/`. Nu se mai copiază aici. Ce era specific acestui repo în fosta
> Partea 1 (statusuri, excepții) e la finalul fișierului.

## [PARTEA 2: SPECIFICAȚII TEHNICE PROIECT]

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
cd ~/Developer/GDCVault && bash build_app.sh
```

Compilează release, împachetează `GDC Vault.app` (cu `AppIcon.icns`),
semnează cu Developer ID Application (dacă `APPLE_SIGN_IDENTITY_APP` e
setat în `~/.zshrc`) și instalează în `/Applications/GDC Vault.app`.

Pentru pachetul complet de release (`.pkg` semnat+notarizat+stapled +
`GDCVault-Mac.zip`):

```bash
cd ~/Developer/GDCVault && bash build_installer.sh
```

## CI/CD (2026-08-24, actualizat 2026-08-26)

Repo-uri publice pe GitHub: `gordasgdc/gdc-vault-mac` + `gordasgdc/gdc-vault-win`.
`.github/workflows/build-mac.yml` — ruleaza pe `macos-latest` la orice push pe
`main`, artefact ad-hoc doar pentru verificare independenta de mediu (**NU**
e sursa pachetului de release — acela se construieste LOCAL, cu certificatul
real din Keychain, vezi mai jos).

## REGULĂ PERMANENTĂ: Locația proiectului pe disc (2026-08-26)
Acest repo trăiește în **`~/Developer/GDCVault`**, NU în `~/Downloads`
(unde a stat inițial — mutat la auditul din 2026-08-26). Motiv: vezi
`~/Developer/GDCPluginManager/PROJECT_STRUCTURE.md`. Windows: `~/Developer/GDCVaultWin`.

## AUDIT 2026-08-26 — găsit și reparat (Directivă Permanentă Supremă)
Raportat de Cristi: la descărcare apărea un folder cu `Instaleaza_GDC_Vault.command`
+ hack Gatekeeper (`xattr -dr com.apple.quarantine`), deși se credea aplicația
deja semnată Apple. **Descoperire reală, nu doar cosmetică**: aplicația era
semnată DOAR ad-hoc (`codesign -dv` pe zip-ul livrat anterior arăta
`flags=0x2(adhoc)`, `TeamIdentifier=not set`) — hack-ul exista tocmai pentru
că Gatekeeper ar fi blocat instalarea fără el, nu era doar "neprofesionist".

Fix real (nu doar eliminarea scriptului):
- `codesigning/` copiat din `CursorPro` (identic — `sign-and-notarize.sh`,
  `entitlements.plist`, `ci-import-certs.sh`, `README.md`).
- `build_app.sh` semnează acum cu Developer ID Application (fallback ad-hoc
  doar dacă `APPLE_SIGN_IDENTITY_APP` nu e setat, pentru build-uri de test).
- `build_installer.sh` (NOU) — `pkgbuild`+`productbuild`+semnare Developer
  ID Installer+notarizare+staple, produce `GDCVault.pkg` + `GDCVault-Mac.zip`
  (3 fișiere la rădăcină: pkg, `Dezinstalare_GDCVault.command`,
  `Instructiuni_Utilizare.pdf`). Verificat local: `pkgutil --check-signature`
  → "signed by a developer certificate issued by Apple for distribution",
  "Notarization: trusted by the Apple notary service".
- `Instaleaza_GDC_Vault.command` (hack Gatekeeper) ȘI `uninstall.sh` (vechi,
  neconform ca nume) — ȘTERSE, înlocuite de `Dezinstalare_GDCVault.command`
  (nou, port 1:1 din CursorPro, plus buclă de ștergere Keychain pentru
  service `com.gordas.gdcvault`).
- `installer/scripts/preinstall` (NOU) — pkill + rm -rf pe instalarea veche,
  cablat via `pkgbuild --scripts`, NIMIC legat de Gatekeeper/quarantine.
- `installer/License.txt` (NOU) — Terms & Conditions pentru panoul de
  licență din installer (productbuild).
- **Ghid PDF multilingv** (`installer/Instructiuni_Utilizare.pdf`, RO/EN/ES,
  3 pagini) — generat cu `installer/generate_pdf.py` (reportlab + font Arial
  TTF, NU fonturile standard-14 PDF — WinAnsiEncoding nu are glyph-uri
  pentru ș/ț românești, ies ca pătrate goale fără font TTF embedat).
  Regenerare: `pip install reportlab pypdf && python3 installer/generate_pdf.py`.
- **Site** (`~/Developer/GDCPluginManager/docs/gdc-vault/index.html`) —
  adăugat switch de limbă RO/EN/ES (pattern `data-i18n` identic cu situl
  principal `docs/index.html`), secțiune nouă "Instalare pe Mac" cu pașii
  corecți (`.pkg` direct, fără launcher), verificat cu `node --check` pe
  scriptul extras înainte de commit (regulă din incidentul JS-crash al
  sitului principal, 2026-08-25 — vezi `GDCPluginManager/CHANGELOG.md`).

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

## Release-țintă de test 2026-08-27 — v0.5.3, FĂRĂ schimbare funcțională
Publicat exclusiv ca țintă pentru testul manual al Self-Updater-ului din
(e) mai jos — la fel ca „v2.5.5 doar ca țintă de test” din DataMover.
Cristi trebuie să instaleze o dată manual `v0.5.2` (prima versiune cu
Self-Updater), apoi să verifice din aplicație că „Actualizează acum”
descarcă+instalează `v0.5.3` fără să deschidă browserul. Fără el, n-ar
exista nimic mai nou de descărcat cu care să testeze fluxul.

## Bug real 2026-08-27 (e) — Self-Updater real (fix-ul de link direct NU era suficient)
Cristi a semnalat, cu screenshot-uri (Mac ȘI Windows): "e la fel, nu e
bine... clientul niciodată nu trebuie să vadă GitHub. Citește CLAUDE.md
din DataMover/MediaFlow-Monitor." Fix-ul anterior (d) doar înlocuise
pagina de release cu link-ul direct al asset-ului — tot deschidea
browserul (doar descărca fișierul în loc de a arăta pagina), nu era ce
face DataMover/gdc-plugin-manager de facto: un **Self-Updater real**, care
descarcă și lansează installer-ul din interiorul aplicației, fără
NICIODATĂ să atingă un tab de browser. Portat 1:1
(`SelfUpdater.swift`, nou) din `DataMover/mac-native/Sources/DataMoverMac/
SelfUpdater.swift`: descarcă `.pkg`-ul cu `URLSession.download` (URL-ul
asset-ului `GDCVault.pkg` citit direct din JSON-ul GitHub API, nu
hardcodat), apoi îl instalează printr-un script bash elevat cu
`osascript ... with administrator privileges` (promptul NATIV de parolă
admin macOS — niciodată `sudo` interactiv, niciodată Terminal vizibil),
care rulează `installer -pkg ... -target /` și relansează aplicația
singur. `UpdateChecker.swift` — `Result.newVersion` acum poartă și URL-ul
`.pkg`-ului găsit în `assets[]`; butonul din alertă (atât cel manual cât
și popup-ul automat din `ContentView.swift`) devine „Actualizează acum”
(nu mai „Descarcă”) și cheamă `SelfUpdater.downloadAndInstall`. Versiune
→ `0.5.2` (PATCH — repară mecanismul de update, nu adaugă UI nou).
**WARNING nemodificat de la DataMover**: pasul de instalare (promptul de
parolă admin) nu poate fi verificat automat de Claude — verificat automat
doar descărcarea reală (HTTP 200, fișier `.pkg` integru pe disc).
Instalarea + relansarea efectivă TREBUIE confirmată manual, o dată, de
Cristi. Oglindă identică pe Windows (installer lansat direct, nesilențios,
tot fără browser — vezi `GDCVaultWin/CLAUDE.md`).

## Bug real 2026-08-27 (d) — "Descarcă" din popup-ul de update deschidea pagina GitHub, nu descărca
Găsit pe Windows de Cristi (aceeași cauză exista identic aici) — butonul
"Descarcă" din alerta de update ȘI din `checkAndShowAlert()` deschideau
`releases/latest` (pagina web), nu asset-ul direct. Fix: ambele acum
deschid `releases/latest/download/GDCVault-Mac.zip` — declanșează
descărcarea fișierului direct, fără pas intermediar pe GitHub. Versiune →
`0.5.1` (PATCH).

## Etapa 2026-08-27 (c) — Conturi multiple, Temă Light/Dark, Setări, Help PDF
Feedback direct Cristi după primul test: (1) **Conturi/departamente
multiple** — `LoginCredential` (nou, VaultEntry.swift) + listă
`additionalLogins: [LoginCredential]`, decodată cu fallback `[]`. Contul
PRINCIPAL rămâne neschimbat pe `VaultEntry` direct; cele suplimentare au
parolă proprie în Keychain (`VaultKeychainStore.*CredentialSecret`, account
`<entryID>.credential.<credID>`, sweep la ștergerea intrării). UI:
`EntryDetailView`, listă dinamică sub parola principală, „Adaugă alt cont/
departament”. (2) **Temă Light/Dark/Sistem** — `ThemeManager.swift` (nou,
port 1:1 din MediaFlow Monitor, `NSApp.appearance`), persistat
`UserDefaults`. (3) **Setări** — `SettingsView.swift` (nou), sheet cu
Picker de temă + buton „Deschide Ghidul de Utilizare (PDF)”, deschis din
roata dințată nouă din footer-ul sidebar-ului (`ContentView.swift`).
(4) **Help PDF accesibil din aplicație** — lipsea complet din UI-ul rulat
(exista doar în arhiva de instalare); `HelpGuide.open()` deschide
`Instructiuni_Utilizare.pdf` din `Bundle.main` — `build_app.sh` ȘI
`build_installer.sh` copiază acum PDF-ul în `Contents/Resources/`, altfel
buildurile locale de dezvoltare nu-l au. Meniul nativ macOS „Help” →
`CommandGroup(replacing: .help)` deschide același ghid. PDF regenerat
(`installer/generate_pdf.py`) cu secțiune nouă „3. Funcții avansate” în
RO/EN/ES (căutare, conturi multiple, asset-uri, temă, setări) —
renumerotare 4/5/6 pentru Trial/Dezinstalare/Suport. Versiune → `0.5.0`
(MINOR). Oglindă identică pe Windows.

## Etapa 2026-08-27 (b) — Bara de căutare fuzzy globală
`FuzzySearch.swift` (nou, GDCVaultCore) — potrivire în 2 trepte: substring
direct, apoi subsecvență de caractere în ordine (insensibil la
majuscule/diacritice/spații) ca "epic sound" să găsească "Epidemic Sound".
`VaultEntry.matchesSearch(_:)` caută în Nume, URL login, Notițe, Resurse
(download/update URL) și TOATE asset-urile cumpărate (nume/serie/link/
folder) — NU în secretele reale din Keychain (parolă/serie a produsului
însuși), doar `PurchasedAsset.licenseKey` e text în clar și intră în
căutare. UI: `.searchable(text:placement:.sidebar)` nativ pe lista din
`ContentView`, filtrare live prin `filteredEntries`. Versiune → `0.4.0`
(MINOR). Oglindă identică pe Windows.

## Etapa 2026-08-27 — Asset-uri cumpărate, Notițe expandabile, Profil compact
Cerință Cristi: (1) Auto-Update — deja 100% funcțional (verificat, fără
modificări); (2) Sidebar redimensionabil — deja nativ prin
`NavigationSplitView` pe Mac (drag pe splitter), fără cod suplimentar;
Notițe: `TextField(axis:.vertical)` → `TextEditor` (110-220pt, scrollbar
nativ); Profil sidebar: `ProfileSidebarBlock` arată acum inline (nu doar
în popover) buton Copy Machine ID + status licență/serie sau buton
"Activează" (`LicenseManager.savedLicenseCode`, nou). (3) Secțiune nouă
"Asset-uri cumpărate & foldere locale" — `PurchasedAsset` (nume, cale
folder, serie, link) în `VaultEntry.purchasedAssets: [PurchasedAsset]`,
decodat cu `decodeIfPresent` + fallback `[]` (backward-compat cu
`entries.json` vechi, fără migrare). UI: listă dinamică în
`EntryDetailView`, `NSOpenPanel(canChooseDirectories:true)` pentru
selectare + `NSWorkspace.selectFile(inFileViewerRootedAtPath:)` pentru
"Deschide Folder". Versiune → `0.3.0` (MINOR, feature nouă vizibilă).
Oglindă identică pe Windows — vezi `GDCVaultWin/CLAUDE.md`.

## Etapa finală (2026-08-26) — Profil/HWID sidebar + Sistem de Revocare Licențe
Port 1:1 din GDC Plugin Manager (vezi CLAUDE.md Partea 1, Regula 12):
`SupabaseConfig.swift`/`RevocationCheck.swift` (GDCVaultCore, noi —
infrastructura Supabase lipsea complet), `AnalyticsClient.swift`,
`UserProfileStore.swift`/`ProfileSidebarBlock.swift` (Nume/Email/Machine
ID în sidebar, sub lista de intrări). `LicenseManager.isUnlocked`
consultă acum și starea de revocare (fail-open). Aceeași migrare SQL
(`is_license_revoked` RPC) ca GDC Plugin Manager — niciun tabel nou.

## Etapa 2026-09-19 — v0.8.1: AppMover cu App Translocation

- `AppMover.swift` portat din GDC Firewall (Regula 40): locația se judecă
  după original (`SecTranslocateCreateOriginalPathForURL`), copia din
  `/Applications` primește carantina FĂRĂ bitul 0x0080 (carantina rămâne),
  o instalare deja izolată se repară pe loc (doar atributul + repornire) —
  niciodată copiere peste sine sau copia instalată la Coș. `~/Applications`
  rămâne acceptat (Regula 18). Față de referință: carantina se ia din
  original; după copiere se verifică că bitul a dispărut (altfel eroare, nu
  buclă); izolată fără bit = nu repornește (fără buclă).
- `DiagnosticLog.swift` nou (Regula 39) → `~/Library/Logs/GDCVault.log` +
  unified log; `scripts/logs.sh`; dezinstalatorul șterge și logul.
- Test live 2026-09-19, macOS 26.6.2, Mac de dezvoltare (SIP dezactivat):
  build notarizat + stapled, zip cu carantină `0083;…;Safari`, dezarhivat cu
  Archive Utility, pornit din `~/Downloads`. Verificat: izolare detectată, instanța 0.8.0 care rula închisă, copiere fără admin (copie a utilizatorului), carantină `0043`, original la Coș, repornit neizolat din `/Applications`, fără prompt la a doua pornire.
- Neverificat: repararea pe loc la GDC Vault (verificată pe Farul, DataMover, MediaFlow — același cod) și calea admin (verificată pe DataMover, MediaFlow). Cu SIP activ (Regula 42) — calea nu folosește
  nimic dependent de SIP, dar n-a rulat pe un astfel de Mac.
- Nepublicat: `update.json`/release rămân pentru scriptul de release.
- **[COMPLETARE 2026-09-19] Publicat**: release `v0.8.1` (pkg versionat + stabil +
  `GDCVault-Mac.zip` cu 3 fișiere), pachet `Notarized Developer ID`;
  `releases/latest/download/*` → 200 pe `v0.8.1`, API-ul GitHub vede `v0.8.1`.

### Completări specifice acestui repo, mutate din fosta Partea 1 (2026-09-18)

Păstrate verbatim. Regula generală la care se referă fiecare e în
`~/Developer/CLAUDE.md`.

**Regula 20:**

**Status acest repo (2026-08-27): IMPLEMENTAT.** `Sources/GDCVault/SelfUpdater.swift` — al treilea port, confirmat funcțional de Cristi (v0.5.2+).

**Regula 21:**

**Status acest repo (2026-08-28, verificat): NU SE APLICA.** Auditat la cererea lui Cristi — GDCVault gestioneaza parole/licente/notite, fara fisiere mari; "Asset-urile cumparate" sunt DOAR referinte catre foldere locale (deschise in Finder), nu copiate/procesate de aplicatie. Regula 21 nu se aplica decat daca se adauga vreodata o functie proprie de copiere/backup de fisiere.

### Jurnal 2026-09-20 — v0.9.0, distribuție DMG (Regula 45 / K)
- `release_dmg.sh` (port din CursorPro): build Developer ID → notarizare + staple → DMG semnat/notarizat/stapled, verificat cu `spctl` și după montare → `dist/GDCVault-0.9.0.dmg` (+ `GDCVault.dmg` stabil). `.zip`/`.command` nu se mai produc; `.pkg` = doar canal legacy updater (≤0.8.1).
- Self-Updater: instalează `.dmg` (versiune + `codesign --verify`); `UpdateChecker` preferă `GDCVault.dmg`, cade pe `.pkg`.
- Keychain (`VaultKeychainStore`, service `com.gordas.gdcvault`, fără access group, AfterFirstUnlock): verificat static; identitatea de semnare (Team 8AR6XP8MG7) e aceeași ca la versiunea instalată → ACL neafectat. Nu există teste automate (`swift test`: fără target). NEverificat: actualizare pe Mac curat.
- **De publicat manual**: release cu `GDCVault-0.9.0.dmg`, `GDCVault.dmg`, `GDCVault.pkg`; pagina `gdc-vault/index.html` din catalog-vendor a fost repointată la DMG (necomisă; pașii de instalare încă vorbesc de „dezarhivare”).
- **LIVE 2026-09-20**: release v0.9.0 publicat pe GitHub (DMG versionat + stabil + `.pkg` legacy, linkuri `latest` 200); `gordas.dev/gdc-vault/` servește pașii de instalare pe DMG.
