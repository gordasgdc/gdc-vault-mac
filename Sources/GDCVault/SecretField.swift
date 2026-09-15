import SwiftUI
import AppKit
import GDCVaultCore

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
    /// Butonul de generare apare doar la parole, nu si la chei de serie —
    /// o serie nu se poate inventa.
    var showsGenerator: Bool = false
    @State private var isRevealed = false
    @State private var justCopied = false
    @State private var showGeneratorPopover = false
    @State private var options = PasswordGenerator.Options()

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
                // Clipboard-ul se goleste singur dupa 45 s — vezi Clipboard.
                Clipboard.copy(value)
                justCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { justCopied = false }
            } label: {
                Image(systemName: justCopied ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .disabled(value.isEmpty)
            .help("Copiază")

            if showsGenerator {
                Button {
                    showGeneratorPopover = true
                } label: {
                    Image(systemName: "wand.and.stars")
                }
                .buttonStyle(.borderless)
                .help("Generează parolă")
                .popover(isPresented: $showGeneratorPopover) {
                    generatorPanel
                }
            }
        }
    }

    @ViewBuilder
    private var generatorPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Generează parolă").font(.headline)
            HStack {
                Text("Lungime: \(options.length)")
                Slider(value: Binding(
                    get: { Double(options.length) },
                    set: { options.length = Int($0) }
                ), in: 8...64, step: 1)
            }
            Toggle("Litere mari", isOn: $options.includeUppercase)
            Toggle("Cifre", isOn: $options.includeDigits)
            Toggle("Simboluri", isOn: $options.includeSymbols)
            Toggle("Evită caractere confundabile (O/0, l/1)", isOn: $options.avoidAmbiguous)
            HStack {
                Spacer()
                Button("Anulează") { showGeneratorPopover = false }
                Button("Folosește") {
                    value = PasswordGenerator.generate(options)
                    isRevealed = true      // o parola pe care n-o vezi nu poate fi verificata
                    showGeneratorPopover = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 320)
    }
}
