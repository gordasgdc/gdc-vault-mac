import AppKit

/// Copiere în clipboard cu ștergere automată.
///
/// DE CE cu verificare înainte de ștergere: dacă între timp ai copiat
/// altceva, o ștergere oarbă ți-ar arunca ce ai copiat tu — de aceea se
/// golește DOAR dacă în clipboard mai e exact valoarea pusă de noi.
/// `changeCount` e contorul sistemului, singurul mod sigur de a afla asta.
enum Clipboard {
    static func copy(_ value: String, clearAfter seconds: TimeInterval = 45) {
        guard !value.isEmpty else { return }
        let board = NSPasteboard.general
        board.clearContents()
        board.setString(value, forType: .string)
        let stamp = board.changeCount

        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            guard NSPasteboard.general.changeCount == stamp else { return }
            NSPasteboard.general.clearContents()
        }
    }
}
