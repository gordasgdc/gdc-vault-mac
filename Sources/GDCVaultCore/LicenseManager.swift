import Foundation

/// Detine starea de proba/licenta a GDC Vault: porneste o proba de 15 zile
/// la prima lansare, persista un cod activat odata introdus, si expune
/// daca aplicatia ar trebui sa fie deblocata acum. Port 1:1 al
/// `LicenseManager.swift` din DataMover (mac-native) — acelasi
/// `LicenseCore`/cheie de semnare, doar productID si durata diferite.
///
/// DECIZIE DE PRODUS (2026-08-24): spre deosebire de DataMover (unde
/// `isUnlocked` blocheaza butonul "Start"), la Vault NU blocam accesul la
/// intrarile deja salvate dupa expirarea probei — un "seif" care te
/// incuie afara de propriile parole ar fi ostil, nu de incredere. Doar
/// `+ Adauga aplicatie` (crearea de intrari NOI) e legata de `isUnlocked`
/// — vezi ContentView.swift. Export/Import/vizualizare raman mereu
/// disponibile.
public final class LicenseManager: ObservableObject {
    public static let shared = LicenseManager()
    public static let productID = "gdc-vault"
    public static let trialDurationDays = 15

    @Published public private(set) var isLicensed = false
    @Published public private(set) var licenseExpiresAt: Int64 = 0 // 0 = perpetuu
    @Published public private(set) var licenseMachineLocked = false
    @Published public var activationError: String?

    private let defaults = UserDefaults.standard
    private let trialStartKey = "gdcvault_trial_start"

    private var activationFileURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("GDC Vault", isDirectory: true)
            .appendingPathComponent("license.txt")
    }

    private init() {
        if defaults.object(forKey: trialStartKey) == nil {
            defaults.set(Date().timeIntervalSince1970, forKey: trialStartKey)
        }
        loadSavedLicense()
    }

    public var trialStartDate: Date {
        Date(timeIntervalSince1970: defaults.double(forKey: trialStartKey))
    }

    /// Zile intregi ramase din proba, rotunjit in sus.
    public var trialDaysRemaining: Int {
        let elapsed = Date().timeIntervalSince(trialStartDate)
        let remaining = Double(Self.trialDurationDays) * 86400 - elapsed
        return max(0, Int(ceil(remaining / 86400)))
    }

    public var isTrialActive: Bool { trialDaysRemaining > 0 }

    /// Verificat inainte de a permite crearea unei intrari NOI (nu si
    /// vizualizarea/editarea celor existente — vezi nota de arhitectura).
    public var isUnlocked: Bool {
        (isLicensed && !RevocationCheck.shared.isRevoked(Self.productID)) || isTrialActive
    }

    /// Reverifica revocarea online (fail-open, vezi RevocationCheck.swift)
    /// — apelata la lansare, niciodata sincron/blocanta pentru UI.
    public func refreshRevocation() async {
        await RevocationCheck.shared.refresh(productIDs: [Self.productID])
    }

    @discardableResult
    public func activate(code: String) -> Bool {
        activationError = nil
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        switch LicenseCore.validate(serial: trimmed, expectedProductID: Self.productID) {
        case .success(let payload):
            saveLicense(code: trimmed)
            applyLicense(payload: payload)
            Task { await RevocationCheck.shared.refresh(productIDs: [Self.productID]) }
            return true
        case .failure(let error):
            activationError = Self.message(for: error)
            return false
        }
    }

    public func deactivate() {
        isLicensed = false
        licenseExpiresAt = 0
        licenseMachineLocked = false
        if let url = activationFileURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func loadSavedLicense() {
        guard let url = activationFileURL,
              let code = try? String(contentsOf: url, encoding: .utf8) else { return }
        if case .success(let payload) = LicenseCore.validate(serial: code, expectedProductID: Self.productID) {
            applyLicense(payload: payload)
        }
    }

    private func applyLicense(payload: LicenseCore.Payload) {
        isLicensed = true
        licenseExpiresAt = payload.expiresAt
        licenseMachineLocked = payload.machineLocked
    }

    private func saveLicense(code: String) {
        guard let url = activationFileURL else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? code.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func message(for error: LicenseCore.ValidationError) -> String {
        switch error {
        case .malformedCode: return "Cod invalid — verifică să nu lipsească vreun caracter."
        case .badSignature: return "Semnătura codului nu se potrivește."
        case .wrongProduct: return "Codul e valid, dar pentru alt produs GDC."
        case .wrongMachine: return "Codul e blocat pe alt calculator."
        case .expired: return "Codul a expirat."
        }
    }
}
