import Foundation
import Security

/// Singurul loc din GDC Vault care atinge un secret in clar. Foloseste
/// Keychain-ul nativ (`kSecClassGenericPassword`) — NU un fisier propriu
/// criptat, ca sa mostenim gratis: criptare la nivel de OS, protectie la
/// export/backup necriptat, si (optional, mai tarziu) Face ID/Touch ID pe
/// citire prin `kSecUseAuthenticationContext`.
///
/// PITFALL FIXED 2026-08-24: prima versiune avea UN SINGUR secret per
/// intrare (fie parola, fie cheia de serie) — dar o fisa unificata de
/// produs poate avea AMBELE simultan (cont de login + cheie de serie
/// pentru același Adobe/Motion Array). Acum fiecare intrare are DOUA
/// sloturi independente in Keychain, distinse prin account:
/// `<id>.password` si `<id>.serial`.
public enum VaultKeychainStore {
    private static let service = "com.gordas.gdcvault"

    public enum SecretSlot: String {
        case password
        case serial
    }

    public enum StoreError: Error {
        case unhandled(OSStatus)
    }

    private static func account(for id: UUID, slot: SecretSlot) -> String {
        "\(id.uuidString).\(slot.rawValue)"
    }

    public static func save(secret: String, forEntryID id: UUID, slot: SecretSlot) throws {
        let account = account(for: id, slot: slot)
        let data = Data(secret.utf8)

        // Sterge orice item vechi pentru acelasi (id, slot) inainte de a
        // scrie — SecItemAdd esueaza cu errSecDuplicateItem daca deja
        // exista.
        try? delete(forEntryID: id, slot: slot)

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

    public static func read(forEntryID id: UUID, slot: SecretSlot) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(for: id, slot: slot),
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
    public static func delete(forEntryID id: UUID, slot: SecretSlot) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(for: id, slot: slot)
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw StoreError.unhandled(status)
        }
    }

    /// Sterge ambele sloturi (parola + serial) pentru o intrare — apelat
    /// la stergerea intregii intrari din Vault.
    public static func deleteAll(forEntryID id: UUID) throws {
        try delete(forEntryID: id, slot: .password)
        try delete(forEntryID: id, slot: .serial)
    }
}
