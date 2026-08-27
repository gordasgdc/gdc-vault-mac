import SwiftUI
import AppKit

/// Panou de Setări (2026-08-27, cerință Cristi: "nu văd unde sunt
/// setări") — temă System/Dark/Light explicită (Regula 18) + acces direct
/// la Ghidul de Utilizare PDF (RO/EN/ES, Regula 8), altfel invizibil din
/// UI-ul rulat (exista doar în arhiva de instalare). Deschis dintr-un
/// buton dedicat (roată dințată) în footer-ul sidebar-ului + din meniul
/// Help.
struct SettingsView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Setări").font(.title2).fontWeight(.bold)

            GroupBox("Aspect") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Temă").font(.caption).foregroundStyle(.secondary)
                    Picker("", selection: Binding(
                        get: { theme.current },
                        set: { theme.set($0) }
                    )) {
                        ForEach(AppTheme.allCases) { t in Text(t.label).tag(t) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("Ajutor") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ghid de utilizare complet — instalare, licențiere, export/import, asset-uri cumpărate — în Română, English și Español.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        HelpGuide.open()
                    } label: {
                        Label("Deschide Ghidul de Utilizare (PDF)", systemImage: "doc.richtext")
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Spacer()
                Button("Închide") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 380)
    }
}

/// Deschide PDF-ul de ghid bundle-uit în Resources (vezi build_app.sh) —
/// dacă lipsește (build de dezvoltare fără packaging complet), arată o
/// eroare clară în loc să nu facă nimic vizibil.
enum HelpGuide {
    static func open() {
        if let url = Bundle.main.url(forResource: "Instructiuni_Utilizare", withExtension: "pdf") {
            NSWorkspace.shared.open(url)
        } else {
            let alert = NSAlert()
            alert.messageText = "Ghidul nu a fost găsit"
            alert.informativeText = "Instructiuni_Utilizare.pdf lipsește din acest build (normal doar pe build-uri de dezvoltare locale, nu pe cele publicate)."
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
