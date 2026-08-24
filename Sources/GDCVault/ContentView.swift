import SwiftUI
import AppKit
import GDCVaultCore

/// Prima versiune de baza: lista + adaugare/editare + banner de expirare.
/// NU are inca licentiere-la-pornire cablata in UI (LicenseCore e deja
/// copiat in GDCVaultCore, gata de folosit cand facem ecranul de
/// activare — vezi LicenseCore.swift / MachineID.swift).
struct ContentView: View {
    @StateObject private var store = VaultMetadataStore()
    @State private var editingEntry: VaultEntry?
    @State private var showingNew = false
    @State private var showImportError = false
    @State private var importErrorMessage = ""

    var body: some View {
        NavigationSplitView {
            List(store.entries) { entry in
                Button {
                    editingEntry = entry
                } label: {
                    VaultRow(entry: entry)
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("GDC Vault")
            .toolbar {
                ToolbarItem {
                    Button {
                        exportVault()
                    } label: {
                        Label("Export…", systemImage: "square.and.arrow.up")
                    }
                }
                ToolbarItem {
                    Button {
                        importVault()
                    } label: {
                        Label("Import…", systemImage: "square.and.arrow.down")
                    }
                }
                ToolbarItem {
                    Button {
                        showingNew = true
                    } label: {
                        Label("Adaugă", systemImage: "plus")
                    }
                }
            }
            .alert("Import eșuat", isPresented: $showImportError) {
                Button("OK") {}
            } message: {
                Text(importErrorMessage)
            }
        } detail: {
            if !store.expiringSoon().isEmpty {
                ExpiringSoonBanner(entries: store.expiringSoon())
            }
            Text("Selectează o intrare din stânga, sau adaugă una nouă.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(item: $editingEntry) { entry in
            EntryEditorView(store: store, existing: entry)
        }
        .sheet(isPresented: $showingNew) {
            EntryEditorView(store: store, existing: nil)
        }
        .frame(minWidth: 720, minHeight: 480)
    }

    private func exportVault() {
        guard let password = PasswordPromptWindow.ask(
            title: "Parolă Master de export",
            message: "Backup-ul (licențe, notițe, parole, atașamente) va fi criptat AES-256 cu această parolă. Reține-o — fără ea, backup-ul nu poate fi restaurat."
        ) else { return }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "gdc-vault-backup.gdcvault"
        panel.message = "Alege unde salvezi backup-ul criptat."
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try VaultExportImport.export(to: url, password: password, entries: store.entries)
        } catch {
            importErrorMessage = "Exportul a eșuat: \(error.localizedDescription)"
            showImportError = true
        }
    }

    private func importVault() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = []
        panel.allowsOtherFileTypes = true
        panel.canChooseDirectories = false
        panel.message = "Alege fișierul de backup (.gdcvault) de importat."
        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard let password = PasswordPromptWindow.ask(
            title: "Parolă Master de import",
            message: "Introdu parola cu care a fost criptat acest backup."
        ) else { return }

        do {
            try VaultExportImport.importBundle(from: url, password: password, into: store)
        } catch VaultExportImport.ExportError.wrongPassword {
            importErrorMessage = "Parolă greșită sau fișier corupt — nu s-a putut decripta backup-ul."
            showImportError = true
        } catch {
            importErrorMessage = "Importul a eșuat: \(error.localizedDescription)"
            showImportError = true
        }
    }
}

private struct VaultRow: View {
    let entry: VaultEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(entry.name).font(.headline)
                Text(entry.kind.displayName).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let days = entry.daysUntilExpiry {
                Text(days < 0 ? "Expirat" : "\(days) zile")
                    .font(.caption)
                    .foregroundStyle(days < 0 ? .red : (days <= 14 ? .orange : .secondary))
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ExpiringSoonBanner: View {
    let entries: [VaultEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Expiră curând", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.headline)
            ForEach(entries) { entry in
                Text("\(entry.name) — \(entry.daysUntilExpiry.map { $0 < 0 ? "expirat" : "\($0) zile" } ?? "")")
                    .font(.subheadline)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding()
    }
}
