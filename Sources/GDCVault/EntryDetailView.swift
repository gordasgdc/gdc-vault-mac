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
struct EntryDetailView: View {
    @ObservedObject var store: VaultMetadataStore
    let isNew: Bool
    let onSaved: (VaultEntry) -> Void
    let onDeleted: () -> Void
    let onCancelNew: () -> Void

    @State private var name: String
    @State private var loginURL: String
    @State private var username: String
    @State private var password: String = "" // gol = "nu schimba parola existenta"
    @State private var licenseType: LicenseType
    @State private var hasExpiry: Bool
    @State private var expiresAt: Date
    @State private var serial: String = ""   // gol = "nu schimba seria existenta"
    @State private var downloadURL: String
    @State private var updateURL: String
    @State private var notes: String
    @State private var attachments: [AttachmentRef]

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
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                TextField("Nume aplicație/produs (ex. Adobe Creative Cloud)", text: $name)
                    .font(.title2)
                    .textFieldStyle(.plain)

                GroupBox("Credențiale") {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("URL login", text: $loginURL).textFieldStyle(.roundedBorder)
                        TextField("Utilizator", text: $username).textFieldStyle(.roundedBorder)
                        SecureField(passwordPlaceholder, text: $password).textFieldStyle(.roundedBorder)
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
                            DatePicker("Expiră la", selection: $expiresAt, displayedComponents: .date)
                        }

                        SecureField(serialPlaceholder, text: $serial).textFieldStyle(.roundedBorder)
                    }
                    .padding(8)
                }

                GroupBox("Resurse") {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Link descărcare", text: $downloadURL).textFieldStyle(.roundedBorder)
                        TextField("Link actualizări (opțional)", text: $updateURL).textFieldStyle(.roundedBorder)
                        TextField("Notițe", text: $notes, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...8)
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

    private var passwordPlaceholder: String {
        isNew ? "Parolă (opțional)" : "Parolă nouă (gol = nu o schimba)"
    }
    private var serialPlaceholder: String {
        isNew ? "Cheie de serie (opțional)" : "Cheie de serie nouă (gol = nu o schimba)"
    }

    private func save() {
        let existing = store.entries.first { $0.id == entryID }

        var entry = VaultEntry(
            id: entryID,
            name: name,
            loginURL: loginURL.isEmpty ? nil : loginURL,
            username: username.isEmpty ? nil : username,
            hasPassword: existing?.hasPassword ?? false,
            licenseType: licenseType,
            expiresAt: hasExpiry ? expiresAt : nil,
            hasSerial: existing?.hasSerial ?? false,
            downloadURL: downloadURL.isEmpty ? nil : downloadURL,
            updateURL: updateURL.isEmpty ? nil : updateURL,
            notes: notes.isEmpty ? nil : notes,
            attachments: attachments
        )

        if !password.isEmpty {
            try? VaultKeychainStore.save(secret: password, forEntryID: entryID, slot: .password)
            entry.hasPassword = true
        }
        if !serial.isEmpty {
            try? VaultKeychainStore.save(secret: serial, forEntryID: entryID, slot: .serial)
            entry.hasSerial = true
        }

        store.upsert(entry)
        onSaved(entry)
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
}
