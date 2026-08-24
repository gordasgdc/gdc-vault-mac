import Foundation
import CryptoKit

/// Backup complet, portabil intre masini/platforme: toate intrarile, cu
/// secretele lor (decriptate din Keychain DOAR cat exista in memorie,
/// niciodata scrise pe disc necriptat) si atasamentele ca bytes inline,
/// tot bundle-ul apoi criptat AES-256-GCM cu o cheie derivata din parola
/// aleasa pe loc de utilizator (PBKDF2, vezi PBKDF2.swift).
///
/// FORMAT FISIER (".gdcvault"), acelasi pe Mac si Windows — vezi
/// VaultExportImport.cs pentru oglinda C#:
///   [8 bytes magic "GDCVLT1\0"][16 bytes salt][AES-GCM combined: 12B nonce + ciphertext + 16B tag]
/// Plaintext-ul criptat e JSON-ul de mai jos (`ExportBundle`).
///
/// De ce inline base64 si nu un .zip separat apoi criptat: un singur
/// blob criptat e mai simplu de portat 1:1 intre Swift si C# (zip +
/// criptare separate ar insemna doua librarii de sincronizat), iar
/// atasamentele dintr-un Vault personal (contracte, facturi) sunt mici
/// si putine — cresterea de ~33% din base64 e neglijabila aici.
public enum VaultExportImport {
    private static let magic: [UInt8] = Array("GDCVLT1\0".utf8) // 8 bytes exact

    public enum ExportError: Error {
        case wrongPassword
        case corruptFile
    }

    private struct ExportAttachment: Codable {
        let ref: AttachmentRef
        let dataBase64: String
    }

    private struct ExportEntry: Codable {
        let entry: VaultEntry
        let secret: String?               // nil daca entry.hasSecret == false
        let attachments: [ExportAttachment]
    }

    private struct ExportBundle: Codable {
        let formatVersion: Int
        let exportedAt: Date
        let entries: [ExportEntry]
    }

    // MARK: - Export

    public static func export(to fileURL: URL, password: String, entries: [VaultEntry]) throws {
        var exportEntries: [ExportEntry] = []
        for entry in entries {
            let secret = entry.hasSecret ? try VaultKeychainStore.read(forEntryID: entry.id) : nil

            var attachments: [ExportAttachment] = []
            for ref in entry.attachments {
                let fileURL = AttachmentStore.fileURL(for: ref, entryID: entry.id)
                let data = try Data(contentsOf: fileURL)
                attachments.append(ExportAttachment(ref: ref, dataBase64: data.base64EncodedString()))
            }

            exportEntries.append(ExportEntry(entry: entry, secret: secret, attachments: attachments))
        }

        let bundle = ExportBundle(formatVersion: 1, exportedAt: Date(), entries: exportEntries)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let plaintext = try encoder.encode(bundle)

        var salt = Data(count: 16)
        _ = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }

        let key = PBKDF2.deriveKey(password: password, salt: salt)
        let sealed = try AES.GCM.seal(plaintext, using: key)

        var output = Data(magic)
        output.append(salt)
        output.append(sealed.combined!)

        try output.write(to: fileURL, options: .atomic)
    }

    // MARK: - Import

    /// Decripteaza si scrie DIRECT in `store`/Keychain/AttachmentStore —
    /// nu intoarce datele in clar catre apelant, ca sa nu existe niciun
    /// moment in care secretele stau in afara Keychain-ului mai mult
    /// decat strict necesar pentru re-salvare.
    @MainActor
    public static func importBundle(from fileURL: URL, password: String, into store: VaultMetadataStore) throws {
        let raw = try Data(contentsOf: fileURL)
        guard raw.count > 8 + 16, raw.prefix(8).elementsEqual(magic) else {
            throw ExportError.corruptFile
        }

        let salt = raw.subdata(in: 8..<24)
        let combined = raw.subdata(in: 24..<raw.count)

        let key = PBKDF2.deriveKey(password: password, salt: salt)

        guard let sealedBox = try? AES.GCM.SealedBox(combined: combined),
              let plaintext = try? AES.GCM.open(sealedBox, using: key) else {
            // AES-GCM autentifica ciphertext-ul: o parola gresita produce
            // un tag invalid, deci `open` arunca — nu descifreaza gunoi.
            throw ExportError.wrongPassword
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let bundle = try decoder.decode(ExportBundle.self, from: plaintext)

        for exportEntry in bundle.entries {
            var entry = exportEntry.entry
            if let secret = exportEntry.secret {
                try VaultKeychainStore.save(secret: secret, forEntryID: entry.id)
                entry.hasSecret = true
            }

            var restoredAttachments: [AttachmentRef] = []
            for attachment in exportEntry.attachments {
                guard let data = Data(base64Encoded: attachment.dataBase64) else { continue }
                let dir = AttachmentStore.directory(for: entry.id)
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let destination = dir.appendingPathComponent(attachment.ref.storedFileName)
                try data.write(to: destination)
                restoredAttachments.append(attachment.ref)
            }
            entry.attachments = restoredAttachments

            store.upsert(entry)
        }
    }
}
