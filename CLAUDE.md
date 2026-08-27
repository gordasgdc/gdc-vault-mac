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

**[COMPLETARE 2026-08-26, închide o lacună de scop reală]** Interdicția de
mai sus se aplică ACUM și produselor din catalogul GDC Plugin Manager
(LUT/DCTL/PowerGrade vândute prin marketplace-ul gratuit) — găsit la audit
un card cu buton „Cumpără" și sume afișate brut („378,00 €"). Butonul
devine „Donează" peste tot (RO/EN/ES); suma documentată de furnizor pentru
acel produs (promoția specifică lui, nu neapărat 23 €) rămâne vizibilă, dar
NICIODATĂ lângă cuvântul „preț"/„cumpără"/„vânzare" — decizia anterioară de
scop (marketplace = "relație comercială diferită, nu se aplică") e
INVALIDATĂ explicit. Excepție: tabelele interne ale Furnizorului (ex.
`SalesHistoryView`, coloana „Preț" din registrul de vânzări al lui Cristi)
nu sunt UI orientat spre client — rămân neatinse.

**15. CRM Furnizor — set minim de funcționalități administrative
(2026-08-26).** Panoul de Clienți al Furnizorului (`SalesHistoryView.swift`)
nu rămâne un log rigid — trebuie să ofere: filtrare rapidă pe produs
(dropdown dinamic, nu hardcodat), export 1-click (clipboard sau fișier) al
email-urilor/HWID-urilor din selecția curentă (filtrată), copiere rapidă
per-câmp direct din tabel (fără să deschizi editarea), Licențiere în Masă
(paste o listă de email-uri/machine ID-uri → generează automat câte o
licență per linie, pentru un produs/durată alese o singură dată), și
editare liberă a duratei unei licențe deja generate (Zile/Luni/Ani/
Lifetime). Furnizorul arată versiunea curentă în UI, la fel ca orice
aplicație client — nu e scutit de Regula 7 doar pentru că e un instrument
intern.

**16. Design Web "Shift" — compact, fără spații goale (2026-08-26).**
Completare la Regula 12: paginile de prezentare NU doar adoptă paleta
amber/cupru — trebuie și dense/aerisite corect, nu găunoase. `min-height:
100svh` pe un hero cu conținut scurt lasă spațiu gol enorm pe orice ecran
mai mare — evită-l sau limitează-l (ex. `78svh`); padding-ul secțiunilor
(`section`) rămâne generos dar nu excesiv (60px, nu 90px+). Orice accent
vechi (verde/teal/albastru folosit ca accent PRIMAR, nu ca stare
semantică precum "verificat cu succes") se înlocuiește cu amber/cupru —
o variabilă CSS poate păstra alt NUME istoric (`--scope`, `--accent-copy`)
atât timp cât VALOAREA ei devine amber, ca să nu rescrii zeci de
apariții `var(--x)` din foaia de stil.

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

**17. Orice fișier descărcabil TREBUIE să poarte numărul versiunii în NUMELE
fișierului (2026-08-26).** Nu doar în interiorul aplicației (Regula 14) —
în numele fizic al pachetului: `DataMover-2.5.5.pkg`, nu `DataMover.pkg`;
`GDCPluginManagerSetup-1.2.8.exe`, nu `GDCPluginManagerSetup.exe`. Motiv
direct de la Cristi: probele/build-urile de test se acumulează local (în
`~/Downloads`, `/tmp`, trimise pentru testare) și devin de nerecunoscut
fără versiune în nume — "am o grămadă de descărcări și nu știu ce versiune
sunt, care, ce și cum sunt".
- **Excepție, NU o contrazicere**: mecanismul `releases/latest/download/
  <nume-stabil>` (site-ul, self-updater-ul) are nevoie STRUCTURAL de un
  nume care nu se schimbă niciodată între release-uri — vezi Regula
  Domeniului & Download. Copia asta stabilă (`DataMover.pkg`,
  `GDCPluginManager.pkg`) tot trebuie publicată, DAR ALĂTURI de copia
  versionată, niciodată singură. `build_installer.sh`/`build_app.sh` din
  fiecare repo produc deja ambele — regula asta cere doar ca ambele să
  ajungă mereu pe release, nu doar cea stabilă.
- **Orice fișier construit/descărcat/trimis lui Cristi în afara acestui
  mecanism** (build local de test, artefact de CI descărcat manual,
  fișier trimis prin `SendUserFile`, copie pusă în `/tmp` pentru
  verificare) TREBUIE redenumit explicit cu versiunea înainte de a fi
  oferit — niciodată livrat cu numele generic/stabil, care are sens doar
  ca țintă a unui link fix, nu ca fișier de sine stătător pe disc.

**18. Standard UX/Arhitectură obligatoriu pentru orice aplicație desktop
NOUĂ, de la primul release (2026-08-26).** Stabilit după MediaFlow Monitor
v1.3.0 — patru cerințe care nu mai sunt opționale pentru nicio aplicație
GDC viitoare (Mac și, unde tehnologia o permite, Windows):
- **Mutare automată în `/Applications` (Mac)** — la lansare, dacă bundle-ul
  rulează în afara `/Applications` sau `~/Applications` (tipic: extras
  direct din `.zip`/Downloads, sub App Translocation), aplicația arată un
  prompt nativ ("Doriți să mutați X în Aplicații?") și, la confirmare,
  copiază bundle-ul, relansează din noua locație și mută originalul la
  Coșul de gunoi. Vezi implementarea de referință `AppMover.swift`
  (MediaFlow Monitor) — fără dependință externă (PFMoveToApplicationsFolder
  nu are un port SPM întreținut), doar `NSAlert` + `FileManager`.
- **Fereastră principală redimensionabilă liber**, cu o dimensiune minimă
  de siguranță (`minSize`/`minWidth`+`minHeight`) sub care conținutul nu
  mai e lizibil — nu ferestre cu dimensiune fixă hardcodată.
- **Selector explicit de temă System/Dark/Light**, independent de setarea
  macOS/Windows — unii clienți vor Light chiar și noaptea, alții Dark
  permanent; NU e suficient să urmezi orbește `prefers-color-scheme`/tema
  sistemului. Persistat local (`UserDefaults`/Registry), aplicat imediat
  fără repornire. Vezi `AppTheme.swift`/`ThemeManager` (MediaFlow Monitor).
- **Protocolul de semnare, notarizare, auto-update și integrare GDC
  Manager rămâne cel deja documentat în Regulile 3, 5, 6, 13, 14, 17** —
  regula asta nu introduce un protocol nou, doar reconfirmă că orice
  aplicație nouă îl respectă de la prima versiune publicată, nu "adăugat
  ulterior quando there's time".

**19. Regulă Legală & Packaging (UE/Global) (2026-08-27).**
- **Pagini Web.** Orice landing page nouă sau actualizare de site publicată
  pe `gordas.dev` (sau pe orice site GDC, inclusiv paginile de proiect
  `gordasgdc.github.io/<repo>`) TREBUIE să conțină în footer link-uri către
  `https://gordas.dev/termeni` (Termeni și Condiții),
  `https://gordas.dev/confidentialitate` (Politică de Confidențialitate
  GDPR) și, unde e relevant, `https://gordas.dev/cookie` (Cookie-uri),
  plus o notă scurtă de statut: *"gordas.dev este o platformă administrată
  de dezvoltatori independenți. Aplicațiile și resursele sunt furnizate ca
  atare (AS IS), iar susținerea proiectului se bazează pe contribuții
  opționale de sprijin și donații."* Sursa canonică a acestor 3 pagini
  legale trăiește în `gdc-plugin-manager-catalog-vendor/docs/` — orice alt
  site GDC linkuiește către ele (absolut), nu le duplică.
- **Installere (.pkg macOS / .exe Windows).** Începând cu următoarele
  versiuni/build-uri (NU retroactiv — fără rebuild al aplicațiilor deja
  publicate doar pentru asta), scripturile de instalare
  (`build_installer.sh`/`productbuild` pe Mac, `installer.iss`/Inno Setup
  pe Windows) TREBUIE să includă un pas de acceptare a licenței (License
  Agreement/SLA), bazat pe un fișier `license.rtf`/`license.txt` cu un
  extras din Termeni și Condiții (statut de proiect independent,
  licențiere legată de Machine ID, natura de donație a susținerii,
  limitarea răspunderii "as is"). Utilizatorul trebuie să apese explicit
  "Agree"/"I accept" înainte ca instalarea să se finalizeze.

  **[COMPLETARE 2026-08-27] Consimțământ obligatoriu (Consent Gate), nu
  doar text afișat.** Nu e suficient ca licența să apară — pasul trebuie
  să blocheze efectiv avansarea fără acceptare explicită:
  - **macOS (`productbuild`/Distribution.xml).** Elementul `<license
    file="License.txt" mime-type="text/plain"/>` din `Distribution.xml`
    (deja folosit de `build_installer.sh` în `gdc-plugin-manager-catalog-vendor`
    și `gdc-vault-mac`) e SUFICIENT — pagina nativă de licență a
    installer-ului macOS oferă mereu doar "Agree"/"Disagree", iar
    "Continue" nu apare fără "Agree" apăsat; nu există flag care s-o
    ocolească. Regula practică: orice `Distribution.xml` nou generat
    TREBUIE să păstreze elementul `<license>` — omiterea lui (ex. un
    installer simplificat fără pas de licență) NU e acceptabilă.
  - **Windows (Inno Setup).** Secțiunea `[Setup]` din `installer.iss`
    TREBUIE să seteze `LicenseFile=license.txt` (sau `.rtf`) — Inno Setup
    arată atunci nativ o pagină cu opțiunile radio "I accept the
    agreement" / "I do not accept", cu butonul "Next" dezactivat până la
    alegerea explicită "I accept". (Dacă vreun installer Windows ar trece
    vreodată pe NSIS în loc de Inno Setup, echivalentul e
    `!insertmacro MUI_PAGE_LICENSE` cu `MUI_LICENSEPAGE_CHECKBOX` definit,
    pentru varianta cu bifă explicită.)
  - Fișierul `license.txt`/`.rtf` folosit la acest pas trebuie să conțină
    (măcar rezumat) cele 4 puncte cheie din Termeni: statut independent
    (non-comercial), licențiere Machine ID, natura de donație a
    susținerii, garanție "as is"/limitarea răspunderii — nu doar un MIT
    License generic.

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
