import Foundation

/// Metadatele unui atasament (contract, factura, screenshot). Fisierul
/// real NU sta in acest struct — doar id-ul si numele original, exact ca
/// `secretRef` din VaultEntry: ce poate sta in JSON necriptat e strict
/// separat de bytes-ii fisierului, care sta pe disc sub `AttachmentStore`.
public struct AttachmentRef: Identifiable, Codable, Equatable {
    public var id: UUID
    public var originalFileName: String   // "factura-storyblocks.pdf" - doar de afisat
    public var addedAt: Date

    /// Numele real de pe disc: `<id>.<extensia originala>`. Pastram
    /// extensia (nu doar id-ul brut) ca sa deschidem fisierul cu
    /// aplicatia corecta din Finder/QuickLook.
    public var storedFileName: String

    public init(id: UUID = UUID(), originalFileName: String, storedFileName: String, addedAt: Date = Date()) {
        self.id = id
        self.originalFileName = originalFileName
        self.storedFileName = storedFileName
        self.addedAt = addedAt
    }
}
