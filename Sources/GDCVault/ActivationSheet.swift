import SwiftUI
import AppKit
import GDCVaultCore

/// Port 1:1 al ActivationSheet.swift din DataMover — introducere cod +
/// buton WhatsApp pentru activarea licentei Lifetime (5€, pret
/// promotional in faza beta — vezi nota din CLAUDE.md si landing page).
/// Codul se genereaza manual din Furnizor (GenerateSerialView.swift,
/// `gdc-vault` in `gdcStandaloneProducts`) dupa ce Cristi primeste
/// mesajul WhatsApp — acelasi flux ca toate celelalte unelte GDC, NU un
/// sistem de plata automatizat.
struct ActivationSheet: View {
    @ObservedObject var license: LicenseManager
    @Binding var isPresented: Bool
    @State private var code: String = ""
    @State private var justCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Activează licența GDC Vault").font(.title2).bold()

            VStack(alignment: .leading, spacing: 4) {
                Text("ID calculator").font(.system(size: 11)).foregroundStyle(.secondary)
                HStack {
                    Text(MachineID.display).font(.system(.body, design: .monospaced))
                    Button(justCopied ? "Copiat" : "Copiază") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(MachineID.display, forType: .string)
                        justCopied = true
                    }
                    .buttonStyle(.bordered)
                }
            }

            TextField("Cod de activare", text: $code)
                .textFieldStyle(.roundedBorder)

            if let error = license.activationError {
                Text(error).foregroundStyle(.red).font(.system(size: 12))
            }

            Text("Licență Lifetime — 5€ (preț promoțional, valabil în faza de dezvoltare/beta; crește după obținerea certificatelor oficiale de semnare Apple/Windows).")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Button {
                NSWorkspace.shared.open(WhatsAppLink.url(text: "Bună, vreau să cumpăr licența GDC Vault (5€). ID calculator: \(MachineID.display)"))
            } label: {
                Label("Cumpără prin WhatsApp", systemImage: "message.fill")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .tint(.green)

            HStack {
                Button("Anulează") { isPresented = false }
                Spacer()
                Button("Activează") {
                    if license.activate(code: code) {
                        isPresented = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 440)
    }
}
