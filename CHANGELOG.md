# Changelog — GDC Vault (Mac)

## v0.2.2 (2026-08-26)
**Completare obligatorie, Directivă Permanentă Supremă — lipsea complet:**
- **Versiune vizibilă în UI**: `v0.2.2` afișat acum în footer-ul sidebar-ului
  (mereu vizibil, nu doar în meniul About) + în panoul standard About
  (Cmd+meniu → Despre GDC Vault).
- **Update checker cu pop-up**: verificare automată la lansare
  (`UpdateChecker.checkSilentlyOnLaunch`, comparație cu ultimul tag GitHub)
  — dacă există o versiune nouă, apare un `.alert` SwiftUI (pop-up real,
  nu doar banner) cu buton „Descarcă" → deschide pagina de releases.
  Dismissal per-versiune (`gdcvault_dismissed_update_version`, UserDefaults) —
  nu reapare la fiecare pornire odată respins. Plus verificare manuală
  („Caută actualizări" — buton în sidebar ȘI în meniu).
- Niciuna din cele două nu exista înainte de acest release — găsit la
  verificare explicită, nu presupus conform.

## v0.2.1 (2026-08-26)
**Doar Mac** — audit critic, aliniere la Directiva Permanentă Supremă:
- **Fix real de semnare**: aplicația era semnată DOAR ad-hoc
  (`TeamIdentifier=not set`) — motivul real pentru care exista hack-ul de
  Gatekeeper. Acum semnată cu Developer ID Application + Installer,
  notarizată și stapled (vezi `CLAUDE.md`, secțiunea Audit 2026-08-26).
- Eliminat `Instaleaza_GDC_Vault.command` (hack `xattr`/quarantine) —
  pachetul e acceptat nativ de Gatekeeper.
- `GDCVault-Mac.zip` conține acum exact 3 fișiere la rădăcină: `GDCVault.pkg`
  (semnat+notarizat), `Dezinstalare_GDCVault.command`,
  `Instructiuni_Utilizare.pdf`.
- Ghid PDF de instalare/utilizare, acum **multilingv (RO/EN/ES)**.
- Pagina de prezentare (`gordas.dev/gdc-vault`) primește switch de limbă
  RO/EN/ES + secțiune nouă cu pașii corecți de instalare (`.pkg` direct).
- Curățare instalare veche mutată în `installer/scripts/preinstall`
  (legitim, fără nimic legat de Gatekeeper).
- Repo relocat din `~/Downloads/gdc-vault-mac` în `~/Developer/GDCVault`.

## v0.1.0 – v0.2.0 (2026-08-24)
Vezi `CLAUDE.md` — arhitectura fișei unificate per produs, export/import
criptat AES-256, integrare licențiere (probă 15 zile, Lifetime 5€),
pagină de prezentare `gordas.dev/gdc-vault`.
