import Foundation

/// Căutare tolerantă la greșeli de tipar (fuzzy) — folosită de bara de
/// căutare din sidebar (2026-08-27). Potrivire în DOUĂ trepte: substring
/// direct (rapid, cazul comun), apoi subsecvență de caractere în ordine
/// (gen "epic sound" → "Epidemic Sound") dacă substring-ul direct nu
/// există — insensibilă la majuscule/diacritice și la spații din query.
public enum FuzzySearch {
    public static func matches(query: String, in text: String?) -> Bool {
        guard let text, !text.isEmpty else { return false }
        let q = normalize(query)
        if q.isEmpty { return true }
        let t = normalize(text)
        if t.contains(q) { return true }
        return isSubsequence(q, in: t)
    }

    private static func normalize(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: " ", with: "")
    }

    private static func isSubsequence(_ needle: String, in haystack: String) -> Bool {
        guard !needle.isEmpty else { return true }
        var needleIdx = needle.startIndex
        for ch in haystack {
            if ch == needle[needleIdx] {
                needleIdx = needle.index(after: needleIdx)
                if needleIdx == needle.endIndex { return true }
            }
        }
        return false
    }
}

/// Căutare globală pe un produs — Nume, URL login, Notițe, Resurse și
/// TOATE asset-urile cumpărate (nume/serie/link/folder). Secretele reale
/// (parolă, cheia de serie A PRODUSULUI) rămân în Keychain, necăutabile
/// aici intenționat — doar `hasSerial`/`hasPassword` sunt booleeni, fără
/// text în clar disponibil fără o cerere explicită de decriptare per
/// intrare. Cheile de serie ale asset-urilor cumpărate SUNT în clar
/// (`PurchasedAsset.licenseKey`, nu e un secret Keychain) — acelea intră
/// în căutare, conform cerinței "Licențe/Serii".
public extension VaultEntry {
    func matchesSearch(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        if FuzzySearch.matches(query: trimmed, in: name) { return true }
        if FuzzySearch.matches(query: trimmed, in: loginURL) { return true }
        if FuzzySearch.matches(query: trimmed, in: notes) { return true }
        if FuzzySearch.matches(query: trimmed, in: downloadURL) { return true }
        if FuzzySearch.matches(query: trimmed, in: updateURL) { return true }
        for login in additionalLogins {
            if FuzzySearch.matches(query: trimmed, in: login.label) { return true }
            if FuzzySearch.matches(query: trimmed, in: login.loginURL) { return true }
            if FuzzySearch.matches(query: trimmed, in: login.username) { return true }
        }
        for asset in purchasedAssets {
            if FuzzySearch.matches(query: trimmed, in: asset.name) { return true }
            if FuzzySearch.matches(query: trimmed, in: asset.licenseKey) { return true }
            if FuzzySearch.matches(query: trimmed, in: asset.downloadURL) { return true }
            if FuzzySearch.matches(query: trimmed, in: asset.folderPath) { return true }
        }
        return false
    }
}
