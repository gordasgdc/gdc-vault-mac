import SwiftUI
import GDCVaultCore

/// Prima versiune de baza: lista + adaugare/editare + banner de expirare.
/// NU are inca licentiere-la-pornire cablata in UI (LicenseCore e deja
/// copiat in GDCVaultCore, gata de folosit cand facem ecranul de
/// activare — vezi LicenseCore.swift / MachineID.swift).
struct ContentView: View {
    @StateObject private var store = VaultMetadataStore()
    @State private var editingEntry: VaultEntry?
    @State private var showingNew = false

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
                        showingNew = true
                    } label: {
                        Label("Adaugă", systemImage: "plus")
                    }
                }
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
