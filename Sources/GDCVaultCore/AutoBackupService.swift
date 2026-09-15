import Foundation
import CryptoKit
import Security

/// Copii de siguranță automate, criptate, ale listei de intrări.
///
/// CE CONȚINE ȘI CE NU: aceleași metadate ca `entries.json` — nume, linkuri,
/// date de expirare, costuri. NU conține parole și chei de serie: acelea stau
/// în Keychain și rămân acolo. O copie de siguranță pierdută nu dezvăluie
/// niciun secret, iar o restaurare nu are nevoie de ele ca să refacă seiful.
///
/// Cheia de criptare e generată o dată, la întâmplare, și ținută în Keychain.
/// Deliberat NU derivată din id-ul mașinii: aceea ar fi fost o „parolă"
/// publică, pe care oricine o poate citi de pe același Mac.
public enum AutoBackupService {

    private static let magic = Data("GDCBAK1\0".utf8)
    private static let keychainService = "com.gordas.gdcvault.backup"
    private static let keychainAccount = "backup-key"

    /// Câte copii păstrăm. 10 acoperă câteva zile de lucru fără să umple
    /// discul — fiecare are câțiva KB.
    private static let keepCount = 10

    public static var backupsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport
            .appendingPathComponent("GDCVault", isDirectory: true)
            .appendingPathComponent("Backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: Cheia

    private static func backupKey() throws -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
           let data = result as? Data, data.count == 32 {
            return SymmetricKey(data: data)
        }

        var raw = Data(count: 32)
        _ = raw.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }
        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: raw,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(add as CFDictionary, nil)
        return SymmetricKey(data: raw)
    }

    // MARK: Scriere

    /// Scrie o copie nouă. Întoarce calea, sau `nil` dacă nu era nimic de
    /// salvat.
    ///
    /// Un seif GOL nu se salvează niciodată: altfel, o pornire în care datele
    /// n-au putut fi citite ar produce o copie goală care, peste câteva
    /// salvări, le-ar împinge afară pe cele bune — exact scenariul împotriva
    /// căruia există acest modul.
    @discardableResult
    public static func backup(entries: [VaultEntry]) -> URL? {
        guard !entries.isEmpty else { return nil }
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let plaintext = try encoder.encode(entries)

            let sealed = try AES.GCM.seal(plaintext, using: backupKey())
            guard let combined = sealed.combined else { return nil }

            let stamp = DateFormatter()
            stamp.dateFormat = "yyyyMMdd_HHmmss"
            let url = backupsDirectory.appendingPathComponent("vault_backup_\(stamp.string(from: Date())).enc")

            var output = magic
            output.append(combined)
            try output.write(to: url, options: .atomic)

            prune()
            return url
        } catch {
            // O copie de siguranță eșuată nu are voie să oprească salvarea
            // reală a datelor — e o plasă de siguranță, nu o condiție.
            return nil
        }
    }

    private static func prune() {
        let files = backupFiles()
        guard files.count > keepCount else { return }
        for url in files.dropFirst(keepCount) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Copiile existente, cea mai NOUĂ prima (sortare după nume — formatul
    /// `yyyyMMdd_HHmmss` e sortabil alfabetic, deci nu depindem de data de
    /// modificare a fișierului, care se poate schimba la o copiere).
    public static func backupFiles() -> [URL] {
        let items = (try? FileManager.default.contentsOfDirectory(
            at: backupsDirectory, includingPropertiesForKeys: nil)) ?? []
        return items
            .filter { $0.pathExtension == "enc" && $0.lastPathComponent.hasPrefix("vault_backup_") }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    // MARK: Citire

    public static func decode(_ url: URL) -> [VaultEntry]? {
        guard let raw = try? Data(contentsOf: url), raw.count > magic.count,
              raw.prefix(magic.count) == magic else { return nil }
        do {
            let box = try AES.GCM.SealedBox(combined: raw.dropFirst(magic.count))
            let plaintext = try AES.GCM.open(box, using: backupKey())
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([VaultEntry].self, from: plaintext)
        } catch {
            return nil
        }
    }

    /// Cea mai recentă copie care chiar se poate decripta ȘI conține intrări.
    /// Se încearcă pe rând, nu doar prima: o copie trunchiată de o închidere
    /// bruscă n-are voie să blocheze recuperarea din cea dinaintea ei.
    public static func latestRestorable() -> (url: URL, entries: [VaultEntry])? {
        for url in backupFiles() {
            if let entries = decode(url), !entries.isEmpty {
                return (url, entries)
            }
        }
        return nil
    }
}
