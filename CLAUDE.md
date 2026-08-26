# GDC Vault (Mac) — note de arhitectură

Aplicație standalone GDC: gestionare centralizată de licențe/abonamente/credențiale
pentru creatori de conținut și editori video. ID produs oficial: `gdc-vault`.

## [PARTEA 1: REGULI GLOBALE ECOSISTEM GDC — identică în toate proiectele GDC]

> Acest bloc e sincronizat manual în `CLAUDE.md`-ul TUTUROR proiectelor din
> `~/Developer/` (CGConvertor, CursorPro, DataMover, GDCPluginManager,
> GDCPluginManagerWin, GDCVault, GDCVaultWin, gdc-plugin-manager-catalog-vendor,
> gdc-plugin-manager-files, gdc-production-manager, gdc-resolve-encoder, și
> orice proiect GDC nou). Dacă modifici o regulă aici, propag-o manual și în
> celelalte 10 fișiere — nu există un fișier partajat/include, fiecare
> `CLAUDE.md` e citit independent per-repo. Vezi jurnalul "Sincronizare
> CLAUDE.md" din secțiunea Partea 2 a fiecărui repo pentru data ultimei
> unificări.

**1. Directoare & structură.** Toate proiectele GDC trăiesc exclusiv în
`~/Developer/<NumeProiect>/`, niciodată în `~/Downloads` sau `~/Desktop`
(curățate automat de CleanMyMac/Hazel pe acest Mac — au șters repo-uri de
sursă în trecut). Niciun repo nou nu se creează/clonează în afara
`~/Developer/`. Certificatele Apple (`.p12`/`.cer`) și orice cheie privată
(`.p8`/`.key`/`.pem`/`.mobileprovision`) stau EXCLUSIV în
`~/Developer/Certificates/` (folder în afara oricărui repo git) — niciodată
comise, indiferent de `.gitignore`.

**2. Securitate — zero secrete în git.** `.git/config` nu conține niciodată
un token în clar în URL-ul remote-ului (`https://user:TOKEN@github.com/...`)
— autentificare exclusiv prin `gh` (credential helper) sau SSH. Orice token
găsit expus se elimină din config imediat; revocarea efectivă din GitHub
Settings e un pas manual al lui Cristi (Claude nu poate revoca un token).
Un secret comis vreodată în istoricul git (verificat cu
`git log --all -p | grep` sau echivalent) trebuie semnalat explicit, nu doar
curățat din starea curentă.

**3. Licențiere & Donație (GDC Plugin Manager / Furnizor).** Toate
aplicațiile standalone GDC folosesc `LicenseCore`/`MachineID` (Ed25519,
aceeași cheie publică hardcodată în tot ecosistemul — copiată byte-for-byte,
NU printr-o dependință de pachet între repo-uri). Probă gratuită implicită:
**15 zile**. Activare manuală prin WhatsApp (ID de mașină pre-completat) →
cod generat din `GenerateSerialView.swift` (Furnizor, `gdcStandaloneProducts`
trebuie să includă `productID`-ul noii aplicații). Valoarea susținerii
aplicației se exprimă EXCLUSIV ca **donație** — sumă implicită de referință
**23 €** dacă nu există alt preț promoțional documentat pentru acea
aplicație — NICIODATĂ cu cuvintele „preț", „cumpără" sau „vânzare" (RO/EN/ES:
niciodată „price"/„buy"/"sale" nici în engleză/spaniolă). Formularea trebuie
să apară clar în: UI-ul aplicației (ecran/pop-up de licență), ghidul PDF, și
orice pagină web dedicată.

**4. Manager de Dependențe (Standard GDC, opt-in).** Aplicația de bază
rămâne lightweight — orice dependință externă opțională/grea (ex. FFmpeg
static) se descarcă LA CERERE, nu bundle-uită implicit dacă poate fi evitat.
Indicator global 🔴/🟢 vizibil în header/meniu: verde doar dacă TOATE
componentele obligatorii (non-opționale) sunt OK; componentele opționale
(ex. Homebrew pe Mac) nu blochează starea verde. Click pe indicator deschide
un panou dedicat ("Verificare & Dependențe Sistem") cu o listă modulară de
componente (model generic `DependencyItem` — id, nume, opțional/obligatoriu,
verificare headless, acțiune, niciodată câmpuri hardcodate per-dependință),
fiecare cu propriul status + buton de acțiune (descărcare automată a unui
binar static, sau copiere comandă de instalare). Verificarea rulează headless
la fiecare deschidere a panoului/meniului, actualizând starea instant.

**5. Instalare Autonomă.** Mac: `.pkg` semnat Developer ID Application +
Installer, notarizat, stapled, cu `pkgbuild --install-location "/"` și
payload la `Applications/<App>.app` — instalare DIRECTĂ în `/Applications`
la dublu-click, fără drag-and-drop manual (verificabil cu
`pkgutil --payload-files`). Windows: installer Inno Setup cu
`DefaultDirName={autopf}\GDC\<App>` (Program Files) sau varianta x86,
scurtături automate Desktop + Start Menu, dezinstalare nativă prin
"Apps & Features" (fără script separat necesar dacă Inno Setup o acoperă).

**6. Packaging Mac — arhivă cu STRICT 3 fișiere.** Orice
`<App>-Mac.zip` livrat clientului conține la rădăcină EXACT: (1)
executabilul/`.pkg`-ul semnat+notarizat+stapled, (2)
`Dezinstalare_<App>.command` (dezinstalare completă: procese, TCC dacă
relevant, `~/Library/Application Support`, `Caches`, `Preferences`,
`Saved Application State`, `Logs`, orice item Keychain scris de aplicație),
(3) `Instructiuni_Utilizare.pdf` (RO/EN/ES). NICIODATĂ hack-uri
`xattr -dr com.apple.quarantine` sau launchere `Instalare_*.command` —
pachetul stapled e acceptat nativ de Gatekeeper. Curățarea unei instalări
vechi se face în `installer/scripts/preinstall` (`pkgbuild --scripts`,
pkill + `rm -rf`), niciodată legat de quarantine.

**7. UI Standard — varianta "Shift".** Temă dark, profesională, inspirată de
paginile de Color din DaVinci Resolve (fundal `#14161A`/`#1A1D22`, accent
cald cupru/amber sau altă culoare distinctă per-aplicație, text `#EDEFF2`).
Număr de versiune vizibil în UI (About/Meniu/Settings/Footer), fără excepție.
Update Checker automat la lansare + verificare manuală, conectat la
`update.json`/GitHub Releases API, cu notificare atât banner discrét CÂT ȘI
pop-up modal (o singură dată per versiune nouă, stare de dismissal comună
între cele două) — un simplu banner nu e suficient. `mandatory: true` în
`update.json` ignoră dismissal-ul anterior.

**8. Documentație PDF — standard ultra-detaliat.** Orice
`Instructiuni_Utilizare.pdf` (RO/EN/ES) se redactează pentru un utilizator
complet începător, zero presupuneri, cu secțiunile relevante aplicației:
(a) Panoul de Dependențe — ce înseamnă 🔴/🟢, pas-cu-pas ce face userul la
roșu (unde dă clic, ce se deschide, ce buton apasă); (b) Homebrew (Mac,
dacă aplicabil) — pași la nivel de acțiune: copiază comanda din aplicație,
deschide Terminal (Spotlight, `⌘+Space`), lipește (`⌘+V`), Enter, apoi
explică parola de Mac cerută (invizibilă la tastare) + Enter din nou;
(c) Fluxul de utilizare + acțiuni post-proces — cum se adaugă
fișiere/date, ce face fiecare buton rezultat; (d) Licență & Donație — trial
gratuit explicit (zile), suma exactă ca donație (niciodată "preț"/"vânzare");
(e) Cum funcționează actualizarea automată — ce înseamnă pop-up-ul de
versiune nouă, ce face butonul „Actualizează acum" vs „Mai târziu", și că
instalarea noii versiuni rămâne un pas asistat (descărcare + reinstalare),
nu un update silențios în fundal.

**9. Checklist obligatoriu la FIECARE release** (păstrat identic cu
"DIRECTIVĂ PERMANENTĂ SUPREMĂ" din jurnalul fiecărui proiect — punctele
1-4 de acolo sunt subsumate integral de punctele 5-8 de mai sus). Site-ul
public al fiecărei aplicații trebuie să pointeze mereu la
`releases/latest/download/...` (HTTP 200 verificat, nu presupus), niciodată
un tag fix.

**10. Comunicare & jurnal.** Fiecare `CLAUDE.md` rămâne un jurnal
append-only (regulile vechi nu se șterg, doar se marchează
**[ÎNVECHIT]** cu motivul dacă sunt explicit invalidate). Răspunsurile
Claude rămân ultra-concise: fără explicații de proces, direct codul/
diff-ul/comenzile și statusul. La orice modificare de cod, comanda exactă
de rebuild local se include la finalul răspunsului.

**11. Sincronizare dinamică a Standardului Master (CONTINUOUS UPDATE,
2026-08-26).** Orice adăugare/modificare/optimizare a unei reguli globale
din ACEASTĂ Partea 1 — indiferent din ce proiect pornește — devine automat
noul Standard Master și TREBUIE propagată manual, în ACELAȘI commit sau
imediat următorul, în `CLAUDE.md`-ul tuturor celorlalte proiecte din
`~/Developer/` (nu doar notată "pentru mai târziu"). Orice aplicație NOUĂ
creată în `~/Developer/` primește Partea 1 (versiunea curentă, completă)
încă din primul `CLAUDE.md` scris pentru ea — nu se pornește niciodată de
la un fișier gol sau parțial. Regula 1 de mai sus ("Dacă modifici o regulă
aici, propag-o manual...") descrie mecanismul; aceasta îl declară
obligatoriu, nu opțional.

**12. Profil Utilizator/HWID în Sidebar, Sistem de Revocare Licențe &
Standard Design Web Mobile/Desktop "Shift" (2026-08-26).**
- **Profil Utilizator opțional, vizibil în sidebar-ul UI** (Mac + Windows,
  pe toate aplicațiile cu licențiere GDC): Nume (sau „Anonim" dacă nu e
  completat), Email, și Machine ID (HWID) — afișate clar, nu ascunse
  într-un submeniu. Portat din modulul Tracker existent (Mac,
  `AnalyticsClient.registerDevice` → Supabase `devices`) — Windows trebuie
  aliniat la aceeași infrastructură, nu una separată.
- **Revocare/blacklist de licențe, prin Supabase** (ACEEAȘI bază de date
  deja folosită de Tracker — niciun backend nou de construit). O licență
  Ed25519 rămâne verificată local (offline-first, nicio schimbare la
  activarea inițială), dar clientul verifică periodic + la lansare (dacă
  există conexiune) un tabel de revocări după `machineID`/serial. **Fail
  OPEN, nu fail closed**: fără conexiune la internet, o licență deja
  activată local CONTINUĂ să funcționeze (nu bricuim un user legitim offline)
  — revocarea se aplică abia la următoarea verificare online reușită.
  Furnizor capătă unelte de revocare instant + editare a perioadei de
  valabilitate a unei licențe existente deja generate.
- **Generare flexibilă de licențe** (Furnizor): selector explicit al
  duratei — Zile / Luni / Ani / Forever (Lifetime) / Valabil până la
  versiunea X — nu doar trial fix + activare permanentă binară.
- **Standard Design Web "Shift"** — orice pagină de prezentare/descărcare
  GDC (`gordas.dev` și paginile dedicate per-aplicație) adoptă design-ul
  dark, minimalist, accent amber/cupru consacrat de CG Convertor
  (`gordas.dev/cg-convertor`) — niciun accent verde vechi sau stil
  nealiniat. Toate paginile trebuie optimizate explicit pentru mobil
  (iOS Safari + Android Chrome), verificat vizual la lățimi de telefon,
  nu doar "responsive by CSS framework".

**13. Update Checker — specificație UX obligatorie (2026-08-26).** La
lansare, aplicația verifică `update.json`/GitHub Releases; dacă versiunea
locală e mai veche, arată un pop-up/modal Shift (nu doar bannerul discret
din Regula 7) cu: numărul noii versiuni, un rezumat scurt al noutăților
(Release Notes, dacă `update.json` le are — câmp opțional, degradează
elegant dacă lipsește), și DOUĂ butoane explicite — **„Actualizează acum"**
(deschide direct link-ul de descărcare a installer-ului/pachetului nou,
`releases/latest/download/...`, și arată userului că trebuie să
instaleze peste versiunea curentă + repornească aplicația — NU e un
self-update silențios, niciun helper nu înlocuiește bundle-ul/exe-ul în
fundal, vezi WARNING-ul deja existent din `UpdateChecker.swift`/`.cs`) și
**„Mai târziu"** (închide fereastra, aceeași stare de dismissal ca
bannerul). Popup-ul apare o singură dată per versiune nouă, cu excepția
`mandatory: true` (reapare la fiecare lansare). Ghidul PDF (Regula 8(e))
trebuie să explice acest flux exact.

**14. Versionare semantică obligatorie la FIECARE schimbare (2026-08-26).**
Orice modificare de cod livrată clientului — oricât de mică — incrementează
numărul de versiune, sincron în TOATE punctele care îl țin (Info.plist Mac,
`.csproj`/`installer.iss` Windows, `docs/update.json`, orice altă constantă
de versiune din acel repo). Format `MAJOR.MINOR.PATCH` (ex. `2.3.1`):
- **PATCH** (ultima cifră, `2.3.0`→`2.3.1`) — orice fix, ajustare, adăugare
  mică sau schimbare care nu rupe compatibilitatea. Cazul implicit, cel mai
  frecvent.
- **MINOR** (cifra din mijloc, `2.3.x`→`2.4.0`) — funcționalitate nouă
  vizibilă (ex. o fază/etapă întreagă ca Panoul de Dependențe sau Profilul
  HWID), fără schimbări radicale de arhitectură.
- **MAJOR** (prima cifră, `2.x.x`→`3.0.0`) — schimbare radicală: rebranding,
  redesign complet de UI, schimbare de arhitectură (ex. sistem nou de
  licențiere), sau orice prag pe care Cristi îl declară explicit "versiune
  majoră".
**De ce**: `UpdateChecker`/`.cs` compară STRICT numărul de versiune din
`update.json` cu cel instalat (`IsNewer`) — înlocuirea unui binar pe un
release existent, PE ACEEAȘI versiune, nu declanșează nicio notificare la
clienții deja instalați (bug real, găsit și reparat 2026-08-26: Windows
Shift UI + Faza 1/3/4 livrate silențios sub `v1.2.22`, fără niciun bump).
Un bump de versiune fără schimbare reală de cod e la fel de greșit ca
schimbarea de cod fără bump — cele două merg mereu împreună, în același
commit.

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

## Etapa finală (2026-08-26) — Profil/HWID sidebar + Sistem de Revocare Licențe
Port 1:1 din GDC Plugin Manager (vezi CLAUDE.md Partea 1, Regula 12):
`SupabaseConfig.swift`/`RevocationCheck.swift` (GDCVaultCore, noi —
infrastructura Supabase lipsea complet), `AnalyticsClient.swift`,
`UserProfileStore.swift`/`ProfileSidebarBlock.swift` (Nume/Email/Machine
ID în sidebar, sub lista de intrări). `LicenseManager.isUnlocked`
consultă acum și starea de revocare (fail-open). Aceeași migrare SQL
(`is_license_revoked` RPC) ca GDC Plugin Manager — niciun tabel nou.
