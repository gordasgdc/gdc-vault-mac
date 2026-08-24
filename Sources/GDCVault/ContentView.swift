import SwiftUI
import AppKit
import GDCVaultCore

/// ARHITECTURA UI (rescrisă 2026-08-24, la cererea lui Cristi): sidebar
/// stânga cu acțiuni PRINCIPALE vizibile direct (nu ascunse într-un meniu
/// mic) — Adaugă/Export/Import deasupra listei — și fișa completă a
/// produsului selectat în dreapta, NU într-un sheet modal. Fiecare
/// intrare = un produs, cu tot ce ține de el (credențiale + licențiere +
/// resurse) pe aceeași fișă — vezi EntryDetailView.
struct ContentView: View {
    @StateObject private var store = VaultMetadataStore()
    @ObservedObject private var license = LicenseManager.shared
    @State private var showActivation = false
    @State private var selectedEntryID: UUID?
    /// Non-nil cât timp se completează o intrare nouă, ÎNCĂ nesalvată —
    /// ținută separat de `store.entries` ca să nu apară în listă (și deci
    /// să nu fie confundată cu o intrare reală) până la primul Salvează.
    @State private var draftEntry: VaultEntry?

    @State private var showImportError = false
    @State private var importErrorMessage = ""

    private var displayedEntry: VaultEntry? {
        if let draftEntry { return draftEntry }
        guard let selectedEntryID else { return nil }
        return store.entries.first { $0.id == selectedEntryID }
    }

    var body: some View {
        VStack(spacing: 0) {
            if !license.isLicensed {
                trialBanner
            }
            mainSplitView
        }
        .sheet(isPresented: $showActivation) {
            ActivationSheet(license: license, isPresented: $showActivation)
        }
    }

    /// Banner discret, mereu vizibil cat timp NU exista o licenta activa
    /// — in proba, arata zilele ramase; dupa expirare, invita la activare.
    /// NU blocheaza nimic singur — vezi gating-ul real pe butonul
    /// "Adauga aplicatie" mai jos (nota de arhitectura din LicenseManager).
    private var trialBanner: some View {
        HStack {
            Text(license.isTrialActive
                 ? "Probă gratuită — \(license.trialDaysRemaining) zile rămase"
                 : "Proba a expirat — poți vizualiza și exporta datele existente")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Button("Donează 5€ pentru licență") { showActivation = true }
                .buttonStyle(.plain)
                .foregroundStyle(.green)
                .font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.08))
    }

    private var mainSplitView: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            if let entry = displayedEntry {
                EntryDetailView(
                    store: store,
                    initialEntry: entry,
                    isNew: draftEntry != nil,
                    onSaved: { saved in
                        draftEntry = nil
                        selectedEntryID = saved.id
                    },
                    onDeleted: {
                        draftEntry = nil
                        selectedEntryID = nil
                    },
                    onCancelNew: {
                        draftEntry = nil
                    }
                )
                .id(entry.id)
            } else {
                ContentUnavailableViewCompat()
            }
        }
        .alert("Import eșuat", isPresented: $showImportError) {
            Button("OK") {}
        } message: {
            Text(importErrorMessage)
        }
        .frame(minWidth: 900, minHeight: 560)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("GDC Vault").font(.title2).fontWeight(.bold)

                Button {
                    guard license.isUnlocked else { showActivation = true; return }
                    draftEntry = VaultEntry(name: "")
                    selectedEntryID = nil
                } label: {
                    Label("Adaugă aplicație", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                HStack(spacing: 8) {
                    Button { exportVault() } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    Button { importVault() } label: {
                        Label("Import", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                }

                if !store.expiringSoon().isEmpty {
                    ExpiringSoonBanner(entries: store.expiringSoon())
                }
            }
            .padding(14)

            Divider()

            List(store.entries, selection: $selectedEntryID) { entry in
                VaultRow(entry: entry).tag(entry.id)
            }
            .listStyle(.sidebar)
            .onChange(of: selectedEntryID) {
                // Selectarea altei intrari din lista anuleaza un draft
                // neterminat — un singur "loc de lucru" la un moment dat.
                if selectedEntryID != nil { draftEntry = nil }
            }
        }
        .frame(minWidth: 260)
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
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name).font(.headline)
                HStack(spacing: 4) {
                    if entry.hasPassword { Image(systemName: "person.badge.key.fill").font(.caption2) }
                    if entry.hasSerial { Image(systemName: "key.fill").font(.caption2) }
                    if entry.licenseType != .none {
                        Text(entry.licenseType.displayName).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            if let days = entry.daysUntilExpiry {
                Text(days < 0 ? "Expirat" : "\(days)z")
                    .font(.caption)
                    .foregroundStyle(days < 0 ? .red : (days <= 14 ? .orange : .secondary))
            }
        }
        .padding(.vertical, 3)
    }
}

private struct ExpiringSoonBanner: View {
    let entries: [VaultEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Expiră curând", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.subheadline).fontWeight(.semibold)
            ForEach(entries) { entry in
                Text("\(entry.name) — \(entry.daysUntilExpiry.map { $0 < 0 ? "expirat" : "\($0) zile" } ?? "")")
                    .font(.caption)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// `ContentUnavailableView` există doar din macOS 14 — proiectul țintește
/// deja `.macOS(.v14)` (vezi Package.swift), dar un echivalent minimal
/// scris de mână evită orice ambiguitate de disponibilitate pe build-uri
/// mai vechi ale toolchain-ului.
private struct ContentUnavailableViewCompat: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "shippingbox").font(.system(size: 40)).foregroundStyle(.secondary)
            Text("Selectează o aplicație din stânga").foregroundStyle(.secondary)
            Text("sau adaugă una nouă cu „Adaugă aplicație”").font(.caption).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
