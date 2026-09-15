import Foundation
import LocalAuthentication
import Security

/// Deblocare o SINGURĂ dată per sesiune + cache în memorie pentru secrete.
///
/// PROBLEMA REPARATĂ: fiecare secret e un item Keychain separat
/// (`<id>.password`, `<id>.serial`), iar fiecare citire era o interogare
/// nouă. La zeci de intrări asta înseamnă zeci de interogări la pornire, iar
/// macOS cere parola brelocului la fiecare, chiar și după „Allow Always" —
/// aceea se aplică unei perechi (aplicație semnată, item), nu sesiunii.
///
/// CE NU AM FĂCUT, deliberat: nu am rescris stocarea într-o singură cheie
/// master peste un fișier criptat. Ar fi rezolvat la fel problema, dar cere
/// migrarea datelor reale deja existente — risc disproporționat față de
/// câștig, când cache-ul de mai jos reduce interogările la cel mult una per
/// secret, per sesiune.
@MainActor
public final class VaultSession: ObservableObject {
    public static let shared = VaultSession()

    /// Contextul de autentificare, creat o dată și REFOLOSIT. Trecut la
    /// fiecare citire prin `kSecUseAuthenticationContext`: Keychain-ul îl
    /// vede deja autentificat și nu mai cere nimic.
    private var context: LAContext?

    /// Secretele deja citite în această sesiune. Se golește la blocare și la
    /// ieșirea din aplicație — nu ajunge niciodată pe disc.
    private var cache: [String: String] = [:]

    @Published public private(set) var isUnlocked = false

    private init() {}

    public var biometryAvailable: Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    /// Cere Touch ID (sau parola Mac-ului ca rezervă) o singură dată.
    ///
    /// `.deviceOwnerAuthentication`, nu `.deviceOwnerAuthenticationWithBiometrics`:
    /// al doilea eșuează pe un Mac fără Touch ID sau după prea multe
    /// încercări, fără nicio cale de a continua. Primul cade automat pe
    /// parola contului.
    @discardableResult
    public func unlock(reason: String = "Deblochează seiful GDC Vault") async -> Bool {
        if isUnlocked { return true }

        let context = LAContext()
        context.localizedCancelTitle = "Anulează"
        // Fără asta, macOS ar cere din nou la fiecare item de Keychain citit
        // în următoarele secunde.
        context.touchIDAuthenticationAllowableReuseDuration = 300

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // Niciun mod de autentificare disponibil (rar, dar posibil):
            // continuăm fără context, ca aplicația să rămână utilizabilă.
            self.context = nil
            isUnlocked = true
            return true
        }

        do {
            let ok = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            if ok {
                self.context = context
                isUnlocked = true
            }
            return ok
        } catch {
            return false
        }
    }

    public func lock() {
        cache.removeAll()
        context?.invalidate()
        context = nil
        isUnlocked = false
    }

    // MARK: Citire prin cache

    /// Secretul unei intrări, citit din Keychain CEL MULT o dată per sesiune.
    public func secret(forEntryID id: UUID, slot: VaultKeychainStore.SecretSlot) -> String? {
        let key = "\(id.uuidString).\(slot.rawValue)"
        if let cached = cache[key] { return cached }
        // `try?` peste o functie care intoarce `String?` da `String??` —
        // aplatizat cu `??  nil` ca sa nu se piarda distinctia intre "eroare"
        // si "nu exista secret".
        let value = (try? VaultKeychainStore.read(forEntryID: id, slot: slot, context: context)) ?? nil
        if let value { cache[key] = value }
        return value
    }

    public func credentialSecret(forEntryID entryID: UUID, credentialID: UUID) -> String? {
        let key = "\(entryID.uuidString).cred.\(credentialID.uuidString)"
        if let cached = cache[key] { return cached }
        let value = (try? VaultKeychainStore.readCredentialSecret(
            forEntryID: entryID, credentialID: credentialID, context: context)) ?? nil
        if let value { cache[key] = value }
        return value
    }

    /// De chemat după orice scriere, ca următoarea citire să nu întoarcă
    /// valoarea veche din cache.
    public func invalidate(entryID: UUID) {
        cache = cache.filter { !$0.key.hasPrefix(entryID.uuidString) }
    }
}
