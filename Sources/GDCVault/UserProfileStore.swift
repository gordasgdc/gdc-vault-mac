import Foundation
import GDCVaultCore

/// Profilul opțional al utilizatorului (Nume/Email) — port 1:1 al
/// UserProfileStore.swift din GDC Plugin Manager (vezi CLAUDE.md,
/// Partea 1, Regula 12). Persistat local (UserDefaults), editabil oricând.
final class UserProfileStore: ObservableObject {
    static let shared = UserProfileStore()

    @Published var name: String {
        didSet { UserDefaults.standard.set(name, forKey: Self.nameKey) }
    }
    @Published var email: String {
        didSet { UserDefaults.standard.set(email, forKey: Self.emailKey) }
    }

    let machineID = MachineID.display

    private static let nameKey = "gdcvault_profile_name"
    private static let emailKey = "gdcvault_profile_email"

    private init() {
        name = UserDefaults.standard.string(forKey: Self.nameKey) ?? ""
        email = UserDefaults.standard.string(forKey: Self.emailKey) ?? ""
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Anonim" : trimmed
    }

    func save(name: String, email: String, sendTelemetry: Bool) {
        self.name = name
        self.email = email
        if sendTelemetry, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            AnalyticsClient.registerDevice(name: name, email: email)
        }
    }
}
