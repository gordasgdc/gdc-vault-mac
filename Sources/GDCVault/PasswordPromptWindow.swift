import AppKit

/// NSAlert cu un NSSecureTextField accesoriu — cel mai scurt drum spre
/// "cere-mi o parola" fara sa construim o fereastra SwiftUI separata
/// doar pentru un singur camp. Folosit pentru parola Master de
/// export/import (vezi VaultExportImport).
@MainActor
enum PasswordPromptWindow {
    static func ask(title: String, message: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Anulează")

        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn, !field.stringValue.isEmpty else { return nil }
        return field.stringValue
    }
}
