import AppKit

/// "Check for Updates" manual — compara versiunea rulata cu ultimul tag de
/// pe GitHub Releases si ofera un link direct de download daca e mai noua.
/// Port 1:1 al UpdateChecker.swift din DataMover/CursorPro. Nu e
/// updater silentios/automat (ar avea nevoie de un helper separat care
/// inlocuieste bundle-ul dupa iesirea aplicatiei) - e varianta simpla,
/// fara infrastructura suplimentara: doar anunta si trimite spre pagina
/// de descarcare.
enum UpdateChecker {
    private static let latestReleaseAPIURL = URL(string: "https://api.github.com/repos/gordasgdc/gdc-vault-mac/releases/latest")!
    private static let releasesPageURL = URL(string: "https://github.com/gordasgdc/gdc-vault-mac/releases/latest")!
    /// BUG FIX 2026-08-27 (raportat de Cristi pe Windows, aceeasi problema
    /// exista si aici): link direct spre asset-ul stabil, nu pagina
    /// release-ului - deschiderea lui DECLANSEAZA descarcarea fisierului.
    private static let directDownloadURL = URL(string: "https://github.com/gordasgdc/gdc-vault-mac/releases/latest/download/GDCVault-Mac.zip")!

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    /// Verificare automata, o singura data per lansare, fara alerta daca
    /// nu exista nimic nou (spre deosebire de butonul manual, care mereu
    /// confirma - vezi checkAndShowAlert). Foloseste acelasi dismissal
    /// per-versiune ca restul ecosistemului GDC, ca un update deja vazut
    /// sa nu reapara la fiecare pornire.
    static func checkSilentlyOnLaunch(onNewVersion: @escaping (String) -> Void) {
        Task {
            if case .newVersion(let version) = await fetchLatestTag() {
                let dismissedKey = "gdcvault_dismissed_update_version"
                if UserDefaults.standard.string(forKey: dismissedKey) == version { return }
                await MainActor.run { onNewVersion(version) }
            }
        }
    }

    static func markDismissed(_ version: String) {
        UserDefaults.standard.set(version, forKey: "gdcvault_dismissed_update_version")
    }

    static func checkAndShowAlert() {
        Task {
            let result = await fetchLatestTag()
            await MainActor.run { presentResult(result) }
        }
    }

    private enum Result {
        case upToDate
        case newVersion(String)
        case error
    }

    private static func fetchLatestTag() async -> Result {
        var request = URLRequest(url: latestReleaseAPIURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String else {
                return .error
            }
            let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            if isVersion(latest, newerThan: currentVersion) {
                return .newVersion(latest)
            }
            return .upToDate
        } catch {
            return .error
        }
    }

    private static func isVersion(_ a: String, newerThan b: String) -> Bool {
        let partsA = a.split(separator: ".").compactMap { Int($0) }
        let partsB = b.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(partsA.count, partsB.count) {
            let x = i < partsA.count ? partsA[i] : 0
            let y = i < partsB.count ? partsB[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    private static func presentResult(_ result: Result) {
        let alert = NSAlert()
        switch result {
        case .upToDate:
            alert.messageText = "Ești la zi"
            alert.informativeText = "Rulezi deja ultima versiune (\(currentVersion))."
            alert.addButton(withTitle: "OK")
            alert.runModal()
        case .newVersion(let version):
            alert.messageText = "Este disponibilă o versiune nouă"
            alert.informativeText = "GDC Vault \(version) este disponibil (tu ai \(currentVersion)). Te rugăm să descarci ultimul installer și să îl instalezi peste versiunea actuală."
            alert.addButton(withTitle: "Descarcă")
            alert.addButton(withTitle: "Mai târziu")
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(directDownloadURL)
            }
            markDismissed(version)
        case .error:
            alert.messageText = "Verificarea a eșuat"
            alert.informativeText = "Nu am putut verifica dacă există o versiune nouă. Verifică-ți conexiunea la internet și încearcă din nou."
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
