import Foundation

/// Persista lista de `VaultEntry` (metadate, FARA secrete) ca JSON in
/// `~/Library/Application Support/GDC Vault/entries.json`. E sigur pentru
/// ca `VaultEntry` nu contine niciodata parola/seria in clar — doar
/// `hasSecret` (bool) si `id`-ul folosit ca sa gasesti secretul in Keychain.
///
/// De ce nu SwiftData: proiectul e mic (zeci-sute de intrari, un singur
/// user), iar JSON simplu se poate citi/repara manual daca ceva merge
/// prost, exact ca `catalog.json` din ecosistemul GDC.
@MainActor
public final class VaultMetadataStore: ObservableObject {
    @Published public private(set) var entries: [VaultEntry] = []

    /// Copia gasita la pornire cand fisierul principal lipsea sau era
    /// necitibil. UI-ul o foloseste ca sa OFERE restaurarea — nu restauram
    /// automat: o suprascriere tacuta a datelor e exact ce nu vrei sa faca o
    /// aplicatie de tip seif.
    @Published public private(set) var recoverableBackup: (url: URL, entries: [VaultEntry])?

    private let fileURL: URL

    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("GDC Vault", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("entries.json")
        load()

        // Copie la fiecare pornire, cu datele deja incarcate. Daca lipsesc,
        // `backup` nu scrie nimic (vezi AutoBackupService).
        AutoBackupService.backup(entries: entries)
    }

    private func load() {
        let data = try? Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let data, let decoded = try? decoder.decode([VaultEntry].self, from: data), !decoded.isEmpty {
            entries = decoded
            return
        }

        // Fisier lipsa, gol sau necitibil (mutare pe alt disc, folder nou,
        // JSON trunchiat de o inchidere brusca). Cautam o copie buna, dar NU
        // o aplicam singuri — vezi `recoverableBackup`.
        entries = []
        if let candidate = AutoBackupService.latestRestorable() {
            recoverableBackup = candidate
        }
    }

    /// Aplica o copie gasita la pornire. Inainte de suprascriere face inca o
    /// copie a starii curente — daca restaurarea e o greseala, se poate
    /// intoarce.
    public func restore(from backup: (url: URL, entries: [VaultEntry])) {
        AutoBackupService.backup(entries: entries)
        entries = backup.entries
        recoverableBackup = nil
        save()
    }

    public func dismissRecovery() { recoverableBackup = nil }

    private func backupCurrentFile() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let previous = try? decoder.decode([VaultEntry].self, from: data) else { return }
        AutoBackupService.backup(entries: previous)
    }

    private func save() {
        // Copie INAINTE de scriere, din ce e ACUM PE DISC — nu din `entries`,
        // care e deja starea noua (upsert/delete modifica lista, apoi cheama
        // save). Diferenta conteaza: o copie a starii noi n-ar folosi la
        // nimic la o revenire, fiindca e exact ce vrei sa anulezi.
        backupCurrentFile()

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    public func upsert(_ entry: VaultEntry) {
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx] = entry
        } else {
            entries.append(entry)
        }
        save()
    }

    /// Sterge intrarea SI secretul asociat din Keychain — altfel ar
    /// ramane un item Keychain orfan pentru un id care nu mai exista
    /// nicaieri in UI (acelasi tip de bug ca fisierele-coperta orfane
    /// din CoverImageStore, doar ca in Keychain nu vezi orfanii cu ochiul
    /// liber).
    public func delete(_ entry: VaultEntry) {
        entries.removeAll { $0.id == entry.id }
        try? VaultKeychainStore.deleteAll(forEntryID: entry.id)
        AttachmentStore.removeAll(for: entry.id)
        save()
    }

    /// Intrari care expira in urmatoarele `withinDays` zile (implicit 14) —
    /// sursa pentru notificarea din UI. Include si cele deja expirate.
    public func expiringSoon(withinDays: Int = 14) -> [VaultEntry] {
        entries.filter { entry in
            guard let days = entry.daysUntilExpiry else { return false }
            return days <= withinDays
        }.sorted { ($0.expiresAt ?? .distantFuture) < ($1.expiresAt ?? .distantFuture) }
    }
}
