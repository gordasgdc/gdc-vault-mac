import SwiftUI
import AppKit

/// Câmp pentru o valoare sensibilă (parolă, cheie de serie) — ascuns
/// implicit (puncte), cu buton „ochi" pentru afișare/ascundere și buton
/// de copiere rapidă în clipboard. NU mai e write-only ("gol = nu
/// schimba") — valoarea reală salvată deja e populată aici la deschidere
/// (vezi EntryDetailView.init, care citește din Keychain), exact cerința
/// explicită 2026-08-24: "parolele și seriile TREBUIE să fie vizibile și
/// ușor de copiat", nu ascunse fără nicio cale de a le revedea.
struct SecretField: View {
    let placeholder: String
    @Binding var value: String
    @State private var isRevealed = false
    @State private var justCopied = false

    var body: some View {
        HStack(spacing: 6) {
            Group {
                if isRevealed {
                    TextField(placeholder, text: $value)
                } else {
                    SecureField(placeholder, text: $value)
                }
            }
            .textFieldStyle(.roundedBorder)

            Button {
                isRevealed.toggle()
            } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
            }
            .buttonStyle(.borderless)
            .help(isRevealed ? "Ascunde" : "Arată")

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
                justCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { justCopied = false }
            } label: {
                Image(systemName: justCopied ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .disabled(value.isEmpty)
            .help("Copiază")
        }
    }
}
