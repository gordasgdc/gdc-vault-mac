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

/// Un asset/pachet cumpărat de la un furnizor (efecte, SFX, LUT-uri) legat
/// de un folder local de pe disc — parte a fișei unui produs, listă
/// dinamică (un produs poate avea mai multe asset-uri cumpărate).
public struct PurchasedAsset: Identifiable, Codable, Equatable {
    public var id: UUID
    public var name: String
    public var folderPath: String?
    public var licenseKey: String?
    public var downloadURL: String?

    public init(id: UUID = UUID(), name: String = "", folderPath: String? = nil,
                licenseKey: String? = nil, downloadURL: String? = nil) {
        self.id = id
        self.name = name
        self.folderPath = folderPath
        self.licenseKey = licenseKey
        self.downloadURL = downloadURL
    }
}

/// Un cont/departament SUPLIMENTAR de login pe același produs (2026-08-27)
/// — ex. Adobe are cont separat pentru departamentul Video și pentru cel
/// de Foto. Contul PRINCIPAL rămâne `loginURL`/`username`/`hasPassword`
/// direct pe VaultEntry (neschimbat, compatibilitate); acestea sunt
/// ADIȚIONALE, listă dinamică. Parola fiecăruia e un slot Keychain propriu
/// — vezi VaultKeychainStore.saveCredentialSecret(forEntryID:credentialID:).
public struct LoginCredential: Identifiable, Codable, Equatable {
    public var id: UUID
    public var label: String       // "Departament Video", "Cont Facturare"
    public var loginURL: String?
    public var username: String?
    public var hasPassword: Bool

    public init(id: UUID = UUID(), label: String = "", loginURL: String? = nil,
                username: String? = nil, hasPassword: Bool = false) {
        self.id = id
        self.label = label
        self.loginURL = loginURL
        self.username = username
        self.hasPassword = hasPassword
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

    // Asset-uri cumpărate & foldere locale (2026-08-27) — decodate cu
    // decodeIfPresent + fallback [] ca intrările vechi din entries.json
    // (fără acest câmp) să rămână decodabile, la fel ca Catalog.audioTracks
    // în GDCPluginManagerCore.
    public var purchasedAssets: [PurchasedAsset]

    // Conturi/departamente suplimentare (2026-08-27) — vezi LoginCredential.
    public var additionalLogins: [LoginCredential]

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
        attachments: [AttachmentRef] = [],
        purchasedAssets: [PurchasedAsset] = [],
        additionalLogins: [LoginCredential] = []
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
        self.purchasedAssets = purchasedAssets
        self.additionalLogins = additionalLogins
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, loginURL, username, hasPassword, licenseType, expiresAt,
             hasSerial, downloadURL, updateURL, notes, attachments, purchasedAssets,
             additionalLogins
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        loginURL = try c.decodeIfPresent(String.self, forKey: .loginURL)
        username = try c.decodeIfPresent(String.self, forKey: .username)
        hasPassword = try c.decodeIfPresent(Bool.self, forKey: .hasPassword) ?? false
        licenseType = try c.decodeIfPresent(LicenseType.self, forKey: .licenseType) ?? .none
        expiresAt = try c.decodeIfPresent(Date.self, forKey: .expiresAt)
        hasSerial = try c.decodeIfPresent(Bool.self, forKey: .hasSerial) ?? false
        downloadURL = try c.decodeIfPresent(String.self, forKey: .downloadURL)
        updateURL = try c.decodeIfPresent(String.self, forKey: .updateURL)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        attachments = try c.decodeIfPresent([AttachmentRef].self, forKey: .attachments) ?? []
        purchasedAssets = try c.decodeIfPresent([PurchasedAsset].self, forKey: .purchasedAssets) ?? []
        additionalLogins = try c.decodeIfPresent([LoginCredential].self, forKey: .additionalLogins) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(loginURL, forKey: .loginURL)
        try c.encodeIfPresent(username, forKey: .username)
        try c.encode(hasPassword, forKey: .hasPassword)
        try c.encode(licenseType, forKey: .licenseType)
        try c.encodeIfPresent(expiresAt, forKey: .expiresAt)
        try c.encode(hasSerial, forKey: .hasSerial)
        try c.encodeIfPresent(downloadURL, forKey: .downloadURL)
        try c.encodeIfPresent(updateURL, forKey: .updateURL)
        try c.encodeIfPresent(notes, forKey: .notes)
        try c.encode(attachments, forKey: .attachments)
        try c.encode(purchasedAssets, forKey: .purchasedAssets)
        try c.encode(additionalLogins, forKey: .additionalLogins)
    }

    /// Zile pana la expirare; negativ daca a expirat deja. nil = nu expira/nu se aplica.
    public var daysUntilExpiry: Int? {
        guard let expiresAt else { return nil }
        let seconds = expiresAt.timeIntervalSinceNow
        return Int((seconds / 86400).rounded(.down))
    }
}
