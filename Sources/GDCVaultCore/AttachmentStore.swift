import Foundation

/// Copiaza/sterge fisiere-atasament pe disc, langa `entries.json` dar
/// intr-un subfolder dedicat per intrare — la fel ca `covers/<id>.*` din
/// CoverImageStore (GDCPluginManagerFurnizor), un folder separat per id
/// face stergerea unei intrari intregi (`removeAll(for:)`) triviala si
/// evita coliziuni de nume intre doua atasamente cu acelasi fisier
/// original ("factura.pdf" la doi clienti diferiti).
public enum AttachmentStore {
    /// `~/Library/Application Support/GDC Vault/Attachments/<entryID>/`
    public static func directory(for entryID: UUID) -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport
            .appendingPathComponent("GDC Vault", isDirectory: true)
            .appendingPathComponent("Attachments", isDirectory: true)
            .appendingPathComponent(entryID.uuidString, isDirectory: true)
    }

    /// Copiaza `source` in folderul intrarii si intoarce referinta gata
    /// de adaugat in `VaultEntry.attachments`. Copiem (nu mutam) — sursa
    /// poate fi orice fisier ales de furnizor prin NSOpenPanel, adesea
    /// dintr-un folder pe care nu vrem sa-l atingem.
    public static func add(source: URL, entryID: UUID) throws -> AttachmentRef {
        let dir = directory(for: entryID)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let id = UUID()
        let ext = source.pathExtension
        let storedName = ext.isEmpty ? id.uuidString : "\(id.uuidString).\(ext)"
        let destination = dir.appendingPathComponent(storedName)
        try FileManager.default.copyItem(at: source, to: destination)

        return AttachmentRef(
            id: id,
            originalFileName: source.lastPathComponent,
            storedFileName: storedName
        )
    }

    public static func fileURL(for attachment: AttachmentRef, entryID: UUID) -> URL {
        directory(for: entryID).appendingPathComponent(attachment.storedFileName)
    }

    /// Idempotent: stergerea unui atasament deja disparut de pe disc nu
    /// trebuie sa arunce (acelasi principiu ca `removeLocalFiles` din
    /// CoverImageStore).
    public static func remove(_ attachment: AttachmentRef, entryID: UUID) {
        try? FileManager.default.removeItem(at: fileURL(for: attachment, entryID: entryID))
    }

    /// Sterge tot folderul unei intrari — apelat cand intrarea insasi
    /// se sterge din Vault, ca sa nu ramana atasamente orfane.
    public static func removeAll(for entryID: UUID) {
        try? FileManager.default.removeItem(at: directory(for: entryID))
    }
}
