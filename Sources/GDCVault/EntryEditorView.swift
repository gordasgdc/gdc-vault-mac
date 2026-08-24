import SwiftUI
import AppKit
import GDCVaultCore

/// Formular unic pentru toate cele 3 tipuri (`VaultEntryKind`) — campurile
/// relevante apar/dispar dupa tipul ales, in loc de 3 ecrane separate.
struct EntryEditorView: View {
    @ObservedObject var store: VaultMetadataStore
    @Environment(\.dismiss) private var dismiss

    @State private var kind: VaultEntryKind
    @State private var name: String
    @State private var hasExpiry: Bool
    @State private var expiresAt: Date
    @State private var downloadURL: String
    @State private var updateURL: String
    @State private var loginURL: String
    @State private var username: String
    @State private var notes: String
    @State private var secret: String = "" // gol = "nu schimba secretul existent"
    @State private var attachments: [AttachmentRef]

    private let entryID: UUID
    private let isNew: Bool

    init(store: VaultMetadataStore, existing: VaultEntry?) {
        self.store = store
        self.isNew = existing == nil
        let e = existing ?? VaultEntry(kind: .perpetualLicense, name: "")
        self.entryID = e.id
        _kind = State(initialValue: e.kind)
        _name = State(initialValue: e.name)
        _hasExpiry = State(initialValue: e.expiresAt != nil)
        _expiresAt = State(initialValue: e.expiresAt ?? Date())
        _downloadURL = State(initialValue: e.downloadURL ?? "")
        _updateURL = State(initialValue: e.updateURL ?? "")
        _loginURL = State(initialValue: e.loginURL ?? "")
        _username = State(initialValue: e.username ?? "")
        _notes = State(initialValue: e.notes ?? "")
        _attachments = State(initialValue: e.attachments)
    }

    var body: some View {
        Form {
            Picker("Tip", selection: $kind) {
                ForEach(VaultEntryKind.allCases) { k in Text(k.displayName).tag(k) }
            }
            TextField("Nume (aplicație/plugin/site)", text: $name)

            Toggle("Are dată de expirare", isOn: $hasExpiry)
            if hasExpiry {
                DatePicker("Expiră la", selection: $expiresAt, displayedComponents: .date)
            }

            if kind == .credential {
                TextField("URL login", text: $loginURL)
                TextField("Utilizator", text: $username)
                SecureField(isNew ? "Parolă" : "Parolă nouă (gol = nu o schimba)", text: $secret)
            } else {
                TextField("Link descărcare", text: $downloadURL)
                TextField("Link actualizări (opțional)", text: $updateURL)
                SecureField(isNew ? "Cheie de serie (opțional)" : "Cheie de serie nouă (gol = nu o schimba)", text: $secret)
            }

            TextField("Notițe", text: $notes, axis: .vertical)

            Section("Atașamente (contracte, facturi, screenshot-uri)") {
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

            HStack {
                if !isNew {
                    Button("Șterge", role: .destructive) {
                        store.delete(VaultEntry(id: entryID, kind: kind, name: name))
                        dismiss()
                    }
                }
                Spacer()
                Button("Anulează") { dismiss() }
                Button("Salvează") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 420)
    }

    private func save() {
        var entry = VaultEntry(
            id: entryID,
            kind: kind,
            name: name,
            expiresAt: hasExpiry ? expiresAt : nil,
            downloadURL: downloadURL.isEmpty ? nil : downloadURL,
            updateURL: updateURL.isEmpty ? nil : updateURL,
            loginURL: loginURL.isEmpty ? nil : loginURL,
            username: username.isEmpty ? nil : username,
            notes: notes.isEmpty ? nil : notes,
            attachments: attachments
        )

        if !secret.isEmpty {
            try? VaultKeychainStore.save(secret: secret, forEntryID: entryID)
            entry.hasSecret = true
        } else {
            // Pastram starea anterioara a hasSecret citind-o din store,
            // ca sa nu "uitam" un secret deja salvat doar pentru ca
            // userul a lasat campul gol la o editare ulterioara.
            entry.hasSecret = store.entries.first(where: { $0.id == entryID })?.hasSecret ?? false
        }

        store.upsert(entry)
        dismiss()
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
