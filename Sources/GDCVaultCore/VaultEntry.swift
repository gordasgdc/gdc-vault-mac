import Foundation

/// Cum se licențiază produsul — parte a fișei unificate, NU mai e un
/// selector exclusiv de "tip de intrare" (vezi nota din 2026-08-24 mai jos).
public enum LicenseType: String, Codable, CaseIterable, Identifiable {
    case none          // doar cont/resurse urmărite, fără licențiere
    case perpetual     // cumpărat definitiv
    case subscription  // abonament recurent

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .none: return "Fără licențiere (doar cont/resurse)"
        case .perpetual: return "Cumpărat definitiv"
        case .subscription: return "Abonament"
        }
    }
}

/// O intrare din Vault = UN PRODUS/APLICAȚIE, cu tot ce ține de el la un
/// loc — credențiale, licențiere, resurse. NU un "tip" ales dintr-un
/// dropdown (asta a fost prima versiune, respinsă de Cristi 2026-08-24:
/// un singur produs real, ex. Adobe/Motion Array, are simultan cont de
/// login ȘI cheie de serie ȘI dată de expirare — separarea în 3 tipuri
/// exclusive obliga la a alege una și a pierde restul).
///
/// Secretele (parolă, cheie de serie) sunt DOUĂ sloturi INDEPENDENTE în
/// Keychain (vezi VaultKeychainStore.SecretSlot) — un produs poate avea
/// ambele, una singură, sau niciuna.
public struct VaultEntry: Identifiable, Codable, Equatable {
    public var id: UUID
    public var name: String              // "Adobe Creative Cloud", "Motion Array"

    // Credențiale
    public var loginURL: String?
    public var username: String?
    public var hasPassword: Bool

    // Licențiere
    public var licenseType: LicenseType
    public var expiresAt: Date?          // relevant mai ales pt. .subscription
    public var hasSerial: Bool

    // Resurse
    public var downloadURL: String?
    public var updateURL: String?
    public var notes: String?
    public var attachments: [AttachmentRef]

    public init(
        id: UUID = UUID(),
        name: String,
        loginURL: String? = nil,
        username: String? = nil,
        hasPassword: Bool = false,
        licenseType: LicenseType = .none,
        expiresAt: Date? = nil,
        hasSerial: Bool = false,
        downloadURL: String? = nil,
        updateURL: String? = nil,
        notes: String? = nil,
        attachments: [AttachmentRef] = []
    ) {
        self.id = id
        self.name = name
        self.loginURL = loginURL
        self.username = username
        self.hasPassword = hasPassword
        self.licenseType = licenseType
        self.expiresAt = expiresAt
        self.hasSerial = hasSerial
        self.downloadURL = downloadURL
        self.updateURL = updateURL
        self.notes = notes
        self.attachments = attachments
    }

    /// Zile pana la expirare; negativ daca a expirat deja. nil = nu expira/nu se aplica.
    public var daysUntilExpiry: Int? {
        guard let expiresAt else { return nil }
        let seconds = expiresAt.timeIntervalSinceNow
        return Int((seconds / 86400).rounded(.down))
    }
}
