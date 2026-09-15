import SwiftUI
import AppKit
import GDCVaultCore

/// Fișa UNIFICATĂ a unui produs — credențiale, licențiere și resurse pe
/// ACEEAȘI fișă, simultan (nu 3 tipuri exclusive de ales dintr-un
/// dropdown — vezi nota de arhitectură din VaultEntry.swift). Randată
/// direct în panoul de detaliu al `NavigationSplitView`, nu într-un sheet
/// modal, ca produsul selectat și fișa lui să fie vizibile în același
/// timp (cerința explicită a lui Cristi, 2026-08-24).
///
/// `ScrollView` + `VStack` + `GroupBox`, NICIODATĂ `Form` pe Mac — vezi
/// pitfall-ul documentat în istoricul acestui fișier (Backspace/Salvează
/// "moarte" într-un `Form`).
/// Stare UI locală per cont suplimentar — parola e citită/scrisă direct
/// din Keychain (vezi VaultKeychainStore.*CredentialSecret), nu ține de
/// LoginCredential (care are doar `hasPassword: Bool`, fără secret).
private struct CredentialRow: Identifiable {
    var id: UUID
    var label: String
    var loginURL: String
    var username: String
    var password: String
}

struct EntryDetailView: View {
    @ObservedObject var store: VaultMetadataStore
    let isNew: Bool
    let onSaved: (VaultEntry) -> Void
    let onDeleted: () -> Void
    let onCancelNew: () -> Void

    @State private var name: String
    @State private var loginURL: String
    @State private var username: String
    @State private var password: String
    @State private var licenseType: LicenseType
    @State private var hasExpiry: Bool
    @State private var expiresAt: Date
    @State private var serial: String
    @State private var downloadURL: String
    @State private var updateURL: String
    @State private var notes: String
    @State private var attachments: [AttachmentRef]
    @State private var purchasedAssets: [PurchasedAsset]
    @State private var additionalLogins: [CredentialRow]
    @State private var reminderEnabled: Bool
    @State private var reminderDaysBefore: [Int]
    @State private var priceText: String
    @State private var billingPeriod: BillingPeriod?
    private let originalCredentialIDs: Set<UUID>

    private let entryID: UUID

    init(store: VaultMetadataStore, initialEntry: VaultEntry, isNew: Bool,
         onSaved: @escaping (VaultEntry) -> Void, onDeleted: @escaping () -> Void, onCancelNew: @escaping () -> Void) {
        self.store = store
        self.isNew = isNew
        self.onSaved = onSaved
        self.onDeleted = onDeleted
        self.onCancelNew = onCancelNew
        self.entryID = initialEntry.id

        _name = State(initialValue: initialEntry.name)
        _loginURL = State(initialValue: initialEntry.loginURL ?? "")
        _username = State(initialValue: initialEntry.username ?? "")
        _licenseType = State(initialValue: initialEntry.licenseType)
        _hasExpiry = State(initialValue: initialEntry.expiresAt != nil)
        _expiresAt = State(initialValue: initialEntry.expiresAt ?? Date())
        _downloadURL = State(initialValue: initialEntry.downloadURL ?? "")
        _updateURL = State(initialValue: initialEntry.updateURL ?? "")
        _notes = State(initialValue: initialEntry.notes ?? "")
        _attachments = State(initialValue: initialEntry.attachments)
        _purchasedAssets = State(initialValue: initialEntry.purchasedAssets)
        _reminderEnabled = State(initialValue: initialEntry.reminderEnabled)
        _reminderDaysBefore = State(initialValue: initialEntry.reminderDaysBefore)
        _priceText = State(initialValue: initialEntry.priceAmount.map {
            $0.truncatingRemainder(dividingBy: 1) == 0 ? String(Int($0)) : String($0)
        } ?? "")
        _billingPeriod = State(initialValue: initialEntry.billingPeriod)

        let entryID = initialEntry.id
        _additionalLogins = State(initialValue: initialEntry.additionalLogins.map { cred in
            CredentialRow(
                id: cred.id,
                label: cred.label,
                loginURL: cred.loginURL ?? "",
                username: cred.username ?? "",
                password: cred.hasPassword
                    ? ((try? VaultKeychainStore.readCredentialSecret(forEntryID: entryID, credentialID: cred.id)) ?? "") : ""
            )
        })
        originalCredentialIDs = Set(initialEntry.additionalLogins.map(\.id))

        // PITFALL FIXED 2026-08-24 (bug critic de UX raportat de Cristi):
        // campurile de parola/serie erau write-only ("gol = nu schimba"),
        // deci userul NU putea revedea ce salvase deja — anula scopul unui
        // "seif". Acum citim valoarea reala din Keychain la deschidere,
        // exact ca username/loginURL — SecretField (eye-toggle + copiere)
        // o afiseaza, ascunsa implicit, dar niciodata inaccesibila.
        _password = State(initialValue: initialEntry.hasPassword
            ? ((try? VaultKeychainStore.read(forEntryID: initialEntry.id, slot: .password)) ?? "") : "")
        _serial = State(initialValue: initialEntry.hasSerial
            ? ((try? VaultKeychainStore.read(forEntryID: initialEntry.id, slot: .serial)) ?? "") : "")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                TextField("Nume aplicație/produs (ex. Adobe Creative Cloud)", text: $name)
                    .font(.title2)
                    .textFieldStyle(.plain)

                GroupBox("Credențiale") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            TextField("URL login", text: $loginURL).textFieldStyle(.roundedBorder)
                            URLLaunchButton(urlText: loginURL)
                        }
                        TextField("Utilizator", text: $username).textFieldStyle(.roundedBorder)
                        SecretField(placeholder: "Parolă", value: $password, showsGenerator: true)

                        if !additionalLogins.isEmpty {
                            Divider().padding(.vertical, 2)
                        }
                        ForEach($additionalLogins) { $login in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    TextField("Etichetă (ex. Departament Video)", text: $login.label)
                                        .textFieldStyle(.roundedBorder)
                                    Button {
                                        additionalLogins.removeAll { $0.id == login.id }
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.plain)
                                }
                                HStack(spacing: 6) {
                                    TextField("URL login", text: $login.loginURL).textFieldStyle(.roundedBorder)
                                    URLLaunchButton(urlText: login.loginURL)
                                }
                                TextField("Utilizator", text: $login.username).textFieldStyle(.roundedBorder)
                                SecretField(placeholder: "Parolă", value: $login.password, showsGenerator: true)
                            }
                            .padding(8)
                            .background(Color.secondary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        Button {
                            additionalLogins.append(CredentialRow(id: UUID(), label: "", loginURL: "", username: "", password: ""))
                        } label: {
                            Label("Adaugă alt cont/departament", systemImage: "plus.circle")
                        }
                    }
                    .padding(8)
                }

                GroupBox("Licențiere") {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Tip", selection: $licenseType) {
                            ForEach(LicenseType.allCases) { t in Text(t.displayName).tag(t) }
                        }
                        .pickerStyle(.menu)

                        Toggle("Are dată de expirare", isOn: $hasExpiry)
                        if hasExpiry {
                            DatePicker("Data reînnoirii / expirare", selection: $expiresAt, displayedComponents: .date)

                            Toggle("Trimite notificare înainte de expirare", isOn: $reminderEnabled)
                            if reminderEnabled {
                                HStack(spacing: 10) {
                                    ForEach([30, 7, 3], id: \.self) { days in
                                        Toggle("\(days) z", isOn: Binding(
                                            get: { reminderDaysBefore.contains(days) },
                                            set: { on in
                                                if on { reminderDaysBefore.append(days) }
                                                else { reminderDaysBefore.removeAll { $0 == days } }
                                            }))
                                        .toggleStyle(.checkbox)
                                    }
                                    Spacer()
                                    Button {
                                        RenewalReminders.exportICS(for: snapshotForReminders())
                                    } label: {
                                        Label("Export în calendar (.ics)", systemImage: "calendar.badge.plus")
                                    }
                                    .help("Se deschide în Calendar și se sincronizează pe telefon")
                                }
                                .font(.caption)
                            }
                        }

                        HStack(spacing: 8) {
                            TextField("Cost (opțional)", text: $priceText)
                                .textFieldStyle(.roundedBorder).frame(width: 120)
                            Picker("", selection: $billingPeriod) {
                                Text("—").tag(BillingPeriod?.none)
                                ForEach(BillingPeriod.allCases) { p in
                                    Text(p.displayName).tag(BillingPeriod?.some(p))
                                }
                            }
                            .labelsHidden().frame(width: 110)
                            Spacer()
                        }

                        SecretField(placeholder: "Cheie de serie", value: $serial)
                    }
                    .padding(8)
                }

                GroupBox("Resurse") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            TextField("Link descărcare", text: $downloadURL).textFieldStyle(.roundedBorder)
                            URLLaunchButton(urlText: downloadURL)
                        }
                        HStack(spacing: 6) {
                            TextField("Link actualizări (opțional)", text: $updateURL).textFieldStyle(.roundedBorder)
                            URLLaunchButton(urlText: updateURL)
                        }
                        Text("Notițe").font(.caption).foregroundStyle(.secondary)
                        TextEditor(text: $notes)
                            .font(.system(size: 13))
                            .frame(minHeight: 110, maxHeight: 220)
                            .scrollContentBackground(.hidden)
                            .padding(6)
                            .background(Color(nsColor: .textBackgroundColor))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                    }
                    .padding(8)
                }

                GroupBox("Asset-uri cumpărate & foldere locale") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach($purchasedAssets) { $asset in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    TextField("Nume asset/pachet (ex. Cinematic SFX Vol 1)", text: $asset.name)
                                        .textFieldStyle(.roundedBorder)
                                    Button {
                                        purchasedAssets.removeAll { $0.id == asset.id }
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.plain)
                                }
                                HStack(spacing: 8) {
                                    TextField("Cale folder local", text: Binding(
                                        get: { asset.folderPath ?? "" },
                                        set: { asset.folderPath = $0.isEmpty ? nil : $0 }
                                    ))
                                    .textFieldStyle(.roundedBorder)
                                    Button("Selectează Folder…") { pickFolder(for: $asset) }
                                    Button("Deschide Folder") { openFolder(asset.folderPath) }
                                        .disabled(asset.folderPath == nil)
                                }
                                HStack(spacing: 8) {
                                    TextField("Serie/licență pachet", text: Binding(
                                        get: { asset.licenseKey ?? "" },
                                        set: { asset.licenseKey = $0.isEmpty ? nil : $0 }
                                    ))
                                    .textFieldStyle(.roundedBorder)
                                    HStack(spacing: 6) {
                                    TextField("Link descărcare", text: Binding(
                                        get: { asset.downloadURL ?? "" },
                                        set: { asset.downloadURL = $0.isEmpty ? nil : $0 }
                                    ))
                                    .textFieldStyle(.roundedBorder)
                                    URLLaunchButton(urlText: asset.downloadURL ?? "")
                                    }
                                }
                            }
                            .padding(8)
                            .background(Color.secondary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        Button {
                            purchasedAssets.append(PurchasedAsset())
                        } label: {
                            Label("Adaugă alt asset/efect", systemImage: "plus.circle")
                        }
                    }
                    .padding(8)
                }

                GroupBox("Atașamente (contracte, facturi, screenshot-uri)") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(attachments) { attachment in
                            HStack {
                                Button(attachment.originalFileName) {
                                    NSWorkspace.shared.open(AttachmentStore.fileURL(for: attachment, entryID: entryID))
                                }
                                .buttonStyle(.link)
                                Spacer()
                                Button {
                                    AttachmentStore.remove(attachment, entryID: entryID)
                                    attachments.removeAll { $0.id == attachment.id }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Button {
                            addAttachment()
                        } label: {
                            Label("Adaugă fișier…", systemImage: "paperclip")
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack {
                    if !isNew {
                        Button("Șterge aplicația", role: .destructive) {
                            store.delete(VaultEntry(id: entryID, name: name))
                            onDeleted()
                        }
                    } else {
                        Button("Anulează") { onCancelNew() }
                    }
                    Spacer()
                    Button("Salvează") { save() }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(24)
        }
        .navigationTitle(name.isEmpty ? "Aplicație nouă" : name)
    }

    /// Camp gol la Salvează = "fara secret" — semantica e acum directa
    /// (ce vezi in camp e ce se salveaza), nu "gol = nu schimba" (bug de
    /// UX fixat 2026-08-24: campul era populat mereu la deschidere, deci
    /// vidarea lui e o alegere explicita a userului de a sterge secretul,
    /// nu un no-op accidental).
    private func save() {
        var entry = VaultEntry(
            id: entryID,
            // BUG REAL (2026-09-15): un nume lipit din browser poate incepe
            // cu newline ("\ncamarenacolor.com"). In lista, SwiftUI randa
            // prima linie GOALA, iar randul parea fara nume. Taiem la
            // salvare, ca datele sa fie curate, nu doar afisarea.
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            loginURL: loginURL.isEmpty ? nil : loginURL,
            username: username.isEmpty ? nil : username,
            licenseType: licenseType,
            expiresAt: hasExpiry ? expiresAt : nil,
            priceAmount: parsedPrice,
            billingPeriod: parsedPrice == nil ? nil : (billingPeriod ?? .monthly),
            reminderEnabled: hasExpiry && reminderEnabled,
            reminderDaysBefore: reminderDaysBefore.sorted(by: >),
            downloadURL: downloadURL.isEmpty ? nil : downloadURL,
            updateURL: updateURL.isEmpty ? nil : updateURL,
            notes: notes.isEmpty ? nil : notes,
            attachments: attachments,
            purchasedAssets: purchasedAssets,
            additionalLogins: additionalLogins.map { row in
                LoginCredential(
                    id: row.id,
                    label: row.label,
                    loginURL: row.loginURL.isEmpty ? nil : row.loginURL,
                    username: row.username.isEmpty ? nil : row.username,
                    hasPassword: !row.password.isEmpty
                )
            }
        )

        if password.isEmpty {
            try? VaultKeychainStore.delete(forEntryID: entryID, slot: .password)
            entry.hasPassword = false
        } else {
            try? VaultKeychainStore.save(secret: password, forEntryID: entryID, slot: .password)
            entry.hasPassword = true
        }

        if serial.isEmpty {
            try? VaultKeychainStore.delete(forEntryID: entryID, slot: .serial)
            entry.hasSerial = false
        } else {
            try? VaultKeychainStore.save(secret: serial, forEntryID: entryID, slot: .serial)
            entry.hasSerial = true
        }

        // Conturi suplimentare: scrie/sterge parola fiecarui rand in slotul
        // sau Keychain propriu, apoi curata secretele randurilor ELIMINATE
        // de user in aceasta sesiune de editare (nu mai apar in
        // additionalLogins, dar existau in originalCredentialIDs).
        for row in additionalLogins {
            if row.password.isEmpty {
                try? VaultKeychainStore.deleteCredentialSecret(forEntryID: entryID, credentialID: row.id)
            } else {
                try? VaultKeychainStore.saveCredentialSecret(row.password, forEntryID: entryID, credentialID: row.id)
            }
        }
        let currentIDs = Set(additionalLogins.map(\.id))
        for removedID in originalCredentialIDs.subtracting(currentIDs) {
            try? VaultKeychainStore.deleteCredentialSecret(forEntryID: entryID, credentialID: removedID)
        }

        store.upsert(entry)
        onSaved(entry)

        // Notificarile se reprogrameaza DUPA salvare, pe intrarea salvata:
        // altfel ar folosi datele din formular, care se pot schimba pana la
        // apasarea butonului.
        let saved = entry
        Task { await RenewalReminders.reschedule(for: saved) }
    }

    /// Virgula zecimala, cum o tasteaza un utilizator roman, nu doar punctul.
    private var parsedPrice: Double? {
        let raw = priceText.replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard !raw.isEmpty, let value = Double(raw), value > 0 else { return nil }
        return value
    }

    /// Intrarea asa cum arata ACUM in formular — pentru exportul .ics, care
    /// trebuie sa reflecte ce vezi pe ecran, nu ultima valoare salvata.
    private func snapshotForReminders() -> VaultEntry {
        VaultEntry(id: entryID, name: name,
                   licenseType: licenseType,
                   expiresAt: hasExpiry ? expiresAt : nil,
                   priceAmount: parsedPrice,
                   billingPeriod: parsedPrice == nil ? nil : (billingPeriod ?? .monthly),
                   reminderEnabled: reminderEnabled,
                   reminderDaysBefore: reminderDaysBefore.sorted(by: >))
    }

    /// NSOpenPanel in loc de `.fileImporter` SwiftUI — acelasi motiv ca
    /// `CoverImageStore.pickFile()`: control direct pe tipurile permise
    /// (PDF + imagini) fara sarcasmul unui `UTType` custom.
    private func addAttachment() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf, .image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = "Alege contracte, facturi sau screenshot-uri de atașat."
        panel.prompt = "Atașează"
        guard panel.runModal() == .OK else { return }

        for url in panel.urls {
            if let ref = try? AttachmentStore.add(source: url, entryID: entryID) {
                attachments.append(ref)
            }
        }
    }

    private func pickFolder(for asset: Binding<PurchasedAsset>) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Alege folderul local unde ai salvat acest asset/pachet."
        panel.prompt = "Selectează"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        asset.wrappedValue.folderPath = url.path
    }

    private func openFolder(_ path: String?) {
        guard let path, !path.isEmpty else { return }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }
}
