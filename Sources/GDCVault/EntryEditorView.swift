import SwiftUI
import AppKit
import GDCVaultCore

/// Formular unic pentru toate cele 3 tipuri (`VaultEntryKind`) — campurile
/// relevante apar/dispar dupa tipul ales, in loc de 3 ecrane separate.
///
/// PITFALL FIXED 2026-08-24: prima versiune folosea `Form` (nativ macOS,
/// randat ca NSTableView) — Backspace/Delete in `SecureField` se pierdea
/// mid-typing (caracterul gresit nu se putea sterge), si Salveaza parea
/// "nefunctional". Restul aplicatiilor GDC (GenerateSerialView.swift,
/// PublishAppView.swift) NU folosesc niciodata `Form` pe Mac, exact din
/// acest motiv — folosesc `ScrollView` + `VStack` + `GroupBox` cu
/// `.textFieldStyle(.roundedBorder)`. Aliniat aici la acelasi tipar.
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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(isNew ? "Intrare nouă" : "Editează intrarea").font(.title2).fontWeight(.semibold)

                Picker("Tip", selection: $kind) {
                    ForEach(VaultEntryKind.allCases) { k in Text(k.displayName).tag(k) }
                }
                .pickerStyle(.menu)

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Nume (aplicație/plugin/site)", text: $name).textFieldStyle(.roundedBorder)

                        Toggle("Are dată de expirare", isOn: $hasExpiry)
                        if hasExpiry {
                            DatePicker("Expiră la", selection: $expiresAt, displayedComponents: .date)
                        }

                        if kind == .credential {
                            TextField("URL login", text: $loginURL).textFieldStyle(.roundedBorder)
                            TextField("Utilizator", text: $username).textFieldStyle(.roundedBorder)
                            SecureField(isNew ? "Parolă" : "Parolă nouă (gol = nu o schimba)", text: $secret)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            TextField("Link descărcare", text: $downloadURL).textFieldStyle(.roundedBorder)
                            TextField("Link actualizări (opțional)", text: $updateURL).textFieldStyle(.roundedBorder)
                            SecureField(isNew ? "Cheie de serie (opțional)" : "Cheie de serie nouă (gol = nu o schimba)", text: $secret)
                                .textFieldStyle(.roundedBorder)
                        }

                        TextField("Notițe", text: $notes, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...6)
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
            .padding(24)
        }
        .frame(width: 460, height: 560)
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
