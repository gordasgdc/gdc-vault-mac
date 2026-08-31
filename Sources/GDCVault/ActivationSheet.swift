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
    @ObservedObject private var pricing = PricingChecker.shared

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

            // Preț dinamic (Regula 27) - vezi PricingChecker. Fail-open pe
            // 5 € (valoarea hardcodata anterior) daca pricing.json nu e
            // accesibil.
            if let promo = pricing.activePromo {
                Text("🔥 \(promo.label): \(formattedPrice(promo.price)) (în loc de \(formattedPrice(pricing.basePrice))) — Licență Lifetime, donație unică, nu un preț de listă.")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.orange)
            } else {
                Text("Licență Lifetime — \(formattedPrice(pricing.effectivePrice)) donație unică, nu un preț de listă. Mă ajută să acopăr costurile de dezvoltare. Ofertă valabilă în faza de dezvoltare/beta; crește după obținerea certificatelor oficiale de semnare Apple/Windows.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Button {
                NSWorkspace.shared.open(WhatsAppLink.url(text: "Bună, vreau să donez \(formattedPrice(pricing.effectivePrice)) pentru licența GDC Vault. ID calculator: \(MachineID.display)"))
            } label: {
                Label("Donează prin WhatsApp", systemImage: "message.fill")
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
        .onAppear { pricing.refresh() }
    }

    private func formattedPrice(_ value: Double) -> String {
        let isWhole = value.truncatingRemainder(dividingBy: 1) == 0
        return "\(isWhole ? String(Int(value)) : String(value)) €"
    }
}
