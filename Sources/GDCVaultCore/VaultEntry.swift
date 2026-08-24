import Foundation

/// Ce tip de intrare e o inregistrare din Vault — determina ce campuri
/// conteaza in UI (o licenta n-are `loginURL`, un credential n-are
/// `expiresAt` obligatoriu) fara sa avem trei struct-uri separate.
public enum VaultEntryKind: String, Codable, CaseIterable, Identifiable {
    case perpetualLicense   // cumparat definitiv, cu/fara serial
    case subscription       // abonament recurent, cu data de reinnoire
    case credential         // user/parola pentru un site/serviciu

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .perpetualLicense: return "Licență (cumpărat definitiv)"
        case .subscription: return "Abonament"
        case .credential: return "Cont / credențiale"
        }
    }
}

/// O intrare din Vault. NU contine niciun secret in clar — `secretRef`
/// e doar cheia sub care parola/seria reala e cautata in Keychain (vezi
/// VaultKeychainStore). Structura asta e ce se salveaza pe disc, in JSON,
/// necriptat: e sigur pentru ca nu are ce sa scurga.
///
/// De ce un `secretRef` si nu direct campul in struct: acelasi motiv ca
/// separarea `PrivateCatalogAuth` din `CatalogModel` in GDCPluginManager —
/// tinem strict separat "ce poate sta pe disc necriptat" de "ce trebuie
/// sa treaca prin Keychain/DPAPI".
public struct VaultEntry: Identifiable, Codable, Equatable {
    public var id: UUID
    public var kind: VaultEntryKind
    public var name: String              // "DaVinci Resolve Studio", "Storyblocks"
    public var expiresAt: Date?          // nil = nu expira / nu se aplica
    public var downloadURL: String?
    public var updateURL: String?
    public var loginURL: String?         // pentru .credential
    public var username: String?         // NU e secret, se afiseaza direct
    public var notes: String?

    /// Contracte/facturi/screenshot-uri legate de aceasta intrare. Doar
    /// referinte aici (vezi AttachmentRef) — bytes-ii fisierelor stau in
    /// `AttachmentStore.directory(for: id)`, niciodata in acest JSON.
    public var attachments: [AttachmentRef]

    /// true daca exista un secret asociat (parola sau serial) stocat in
    /// Keychain sub cheia `id.uuidString`. Setat/citit de VaultKeychainStore,
    /// nu de UI direct.
    public var hasSecret: Bool

    public init(
        id: UUID = UUID(),
        kind: VaultEntryKind,
        name: String,
        expiresAt: Date? = nil,
        downloadURL: String? = nil,
        updateURL: String? = nil,
        loginURL: String? = nil,
        username: String? = nil,
        notes: String? = nil,
        attachments: [AttachmentRef] = [],
        hasSecret: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.expiresAt = expiresAt
        self.downloadURL = downloadURL
        self.updateURL = updateURL
        self.loginURL = loginURL
        self.username = username
        self.notes = notes
        self.attachments = attachments
        self.hasSecret = hasSecret
    }

    /// Zile pana la expirare; negativ daca a expirat deja. nil = nu expira.
    public var daysUntilExpiry: Int? {
        guard let expiresAt else { return nil }
        let seconds = expiresAt.timeIntervalSinceNow
        return Int((seconds / 86400).rounded(.down))
    }
}
