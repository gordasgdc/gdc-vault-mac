import SwiftUI
import AppKit
import GDCVaultCore

/// Buton de deschidere a unui link în browserul sistemului.
/// Dezactivat automat când textul nu e o adresă utilizabilă (vezi
/// `isLaunchableURL`) — un buton activ care nu face nimic e mai rău decât
/// unul gri.
struct URLLaunchButton: View {
    let urlText: String

    var body: some View {
        Button {
            guard let url = URL(string: urlText.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
            NSWorkspace.shared.open(url)
        } label: {
            Image(systemName: "arrow.up.right.square")
        }
        .buttonStyle(.borderless)
        .disabled(!isLaunchableURL(urlText))
        .help(isLaunchableURL(urlText) ? "Deschide în browser" : "Adresa trebuie să înceapă cu https://")
    }
}
