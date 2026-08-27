import SwiftUI
import AppKit

@main
struct GDCVaultApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("Despre GDC Vault") { showAboutPanel() }
            }
            CommandGroup(after: .appInfo) {
                Button("Caută actualizări…") { UpdateChecker.checkAndShowAlert() }
            }
            CommandGroup(replacing: .help) {
                Button("Ghid de Utilizare GDC Vault (PDF)") { HelpGuide.open() }
            }
        }
    }

    private func showAboutPanel() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "GDC Vault",
            .applicationVersion: UpdateChecker.currentVersion,
            .credits: NSAttributedString(string: "© \(Calendar.current.component(.year, from: Date())) GDC. Toate drepturile rezervate."),
        ])
    }
}
