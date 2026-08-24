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

    private let fileURL: URL

    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("GDC Vault", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("entries.json")
        load()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        entries = (try? decoder.decode([VaultEntry].self, from: data)) ?? []
    }

    private func save() {
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
        try? VaultKeychainStore.delete(forEntryID: entry.id)
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
