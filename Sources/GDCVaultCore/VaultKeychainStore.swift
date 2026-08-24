import Foundation
import Security

/// Singurul loc din GDC Vault care atinge un secret in clar. Foloseste
/// Keychain-ul nativ (`kSecClassGenericPassword`) — NU un fisier propriu
/// criptat, ca sa mostenim gratis: criptare la nivel de OS, protectie la
/// export/backup necriptat, si (optional, mai tarziu) Face ID/Touch ID pe
/// citire prin `kSecUseAuthenticationContext`.
///
/// Service e fix ("com.gordas.gdcvault"), account e `entry.id.uuidString`
/// — o intrare Vault = un item Keychain. Asta face stergerea unei intrari
/// simpla (un singur `delete`) si evita coliziuni intre doua intrari cu
/// acelasi nume afisat.
public enum VaultKeychainStore {
    private static let service = "com.gordas.gdcvault"

    public enum StoreError: Error {
        case unhandled(OSStatus)
    }

    public static func save(secret: String, forEntryID id: UUID) throws {
        let account = id.uuidString
        let data = Data(secret.utf8)

        // Sterge orice item vechi pentru acelasi id inainte de a scrie —
        // SecItemAdd esueaza cu errSecDuplicateItem daca deja exista, si
        // SecItemUpdate ar complica inutil query-ul pentru un caz atat de rar
        // (schimbarea unei parole existente).
        try? delete(forEntryID: id)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            // .afterFirstUnlock, nu .whenUnlocked: Vault trebuie sa poata
            // porni si citi secrete dintr-un LaunchAgent/verificare de
            // update la boot, nu doar cat timp userul e logat activ.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw StoreError.unhandled(status) }
    }

    public static func read(forEntryID id: UUID) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw StoreError.unhandled(status)
        }
        return String(data: data, encoding: .utf8)
    }

    /// Idempotent: stergerea unei intrari fara secret nu trebuie sa arunce.
    public static func delete(forEntryID id: UUID) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw StoreError.unhandled(status)
        }
    }
}
