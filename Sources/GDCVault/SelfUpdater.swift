import AppKit

/// Descarca si instaleaza automat un update de aplicatie, fara sa mai
/// treaca prin browser/pagina de GitHub — port 1:1 al SelfUpdater.swift
/// din DataMover/gdc-plugin-manager-catalog-vendor (vezi CLAUDE.md
/// Partea 1). Vezi UpdateChecker.swift pentru contextul complet.
///
/// WARNING: pasul de instalare (promptul de parola admin) NU poate fi
/// verificat automat de Claude — cere interactiune fizica reala a userului
/// cu fereastra de sistem. Ce s-a verificat automat: descarcarea (URL
/// valid, HTTP 200, fisier scris integral pe disc) si scriptul generat
/// (sintaxa bash valida). Instalarea efectiva TREBUIE confirmata manual,
/// o data, de Cristi, inainte sa consideram fluxul complet dovedit.
enum SelfUpdater {

    enum UpdateError: LocalizedError {
        case downloadFailed(String)
        case installScriptFailed(String)

        var errorDescription: String? {
            switch self {
            case .downloadFailed(let detail): return "Descărcarea a eșuat: \(detail)"
            case .installScriptFailed(let detail): return "Nu am putut porni instalarea: \(detail)"
            }
        }
    }

    @MainActor
    static func downloadAndInstall(pkgURL: URL, version: String) async {
        let progress = UpdateProgressWindow(version: version)
        progress.show()

        do {
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("gdcvault-update-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let pkgPath = tempDir.appendingPathComponent("GDCVault-\(version).pkg")

            progress.setStatus("Se descarcă actualizarea…")
            try await download(from: pkgURL, to: pkgPath)

            progress.setStatus("Se instalează…")
            try runInstaller(pkgPath: pkgPath, tempDir: tempDir)

            // Scriptul de instalare (pornit mai sus, ruleaza independent sub
            // osascript) se ocupa de tot ce urmeaza: instalare + relansare.
            progress.close()
            NSApp.terminate(nil)
        } catch {
            progress.close()
            presentFailure(error, fallbackURL: releasesPageURLForFallback)
        }
    }

    // MARK: - Descarcare

    private static func download(from url: URL, to destination: URL) async throws {
        let (tempLocation, response): (URL, URLResponse)
        do {
            (tempLocation, response) = try await URLSession.shared.download(from: url)
        } catch {
            throw UpdateError.downloadFailed(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw UpdateError.downloadFailed("HTTP \(code)")
        }
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: tempLocation, to: destination)
    }

    // MARK: - Instalare

    /// Genereaza si porneste (fara sa astepte) scriptul de instalare,
    /// elevat printr-un singur prompt nativ de parola admin.
    private static func runInstaller(pkgPath: URL, tempDir: URL) throws {
        let logPath = tempDir.appendingPathComponent("gdcvault_update.log")
        let scriptPath = tempDir.appendingPathComponent("gdcvault_update.sh")

        let scriptContent = """
        #!/bin/bash
        exec > "\(logPath.path)" 2>&1
        sleep 2
        echo "Instalez actualizarea..."
        installer -pkg "\(pkgPath.path)" -target /
        status=$?
        if [ $status -ne 0 ]; then
            echo "Instalarea a esuat (cod $status)."
            exit $status
        fi
        echo "Pornesc aplicatia actualizata..."
        open -a "GDC Vault"
        rm -rf "\(tempDir.path)"
        """
        do {
            try scriptContent.write(to: scriptPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)
        } catch {
            throw UpdateError.installScriptFailed(error.localizedDescription)
        }

        // `osascript ... with administrator privileges` = prompt NATIV
        // macOS de parola, fara Terminal si fara `sudo` interactiv (care
        // s-ar bloca, fara TTY).
        let escapedPath = scriptPath.path.replacingOccurrences(of: "\"", with: "\\\"")
        let appleScript = "do shell script \"\(escapedPath)\" with administrator privileges"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", appleScript]
        do {
            try process.run()
        } catch {
            throw UpdateError.installScriptFailed(error.localizedDescription)
        }
        // Fire-and-forget INTENTIONAT: promptul de parola e modal la nivel
        // de SISTEM, iar `installer` + relansarea mai dureaza cateva
        // secunde dupa ce userul introduce parola.
    }

    // MARK: - Eroare

    private static let releasesPageURLForFallback = URL(string: "https://github.com/gordasgdc/gdc-vault-mac/releases/latest")!

    @MainActor
    private static func presentFailure(_ error: Error, fallbackURL: URL) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Actualizarea a eșuat"
        alert.informativeText = "\(error.localizedDescription)\n\nPoți descărca manual ultima versiune de pe pagina de GitHub."
        alert.addButton(withTitle: "Deschide pagina")
        alert.addButton(withTitle: "OK")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(fallbackURL)
        }
    }
}

/// Fereastra minimala de progres (AppKit) — doar text + spinner
/// indeterminat, pachetele GDC Vault sunt mici (sub 1MB).
@MainActor
final class UpdateProgressWindow {
    private let window: NSWindow
    private let statusLabel: NSTextField
    private let spinner: NSProgressIndicator

    init(version: String) {
        let contentRect = NSRect(x: 0, y: 0, width: 360, height: 110)
        window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.title = "Actualizare"
        window.isReleasedWhenClosed = false
        window.center()

        let container = NSView(frame: contentRect)

        let titleLabel = NSTextField(labelWithString: "GDC Vault \(version)")
        titleLabel.font = .boldSystemFont(ofSize: 13)
        titleLabel.frame = NSRect(x: 20, y: 70, width: 320, height: 20)
        container.addSubview(titleLabel)

        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 2
        statusLabel.frame = NSRect(x: 20, y: 30, width: 320, height: 34)
        container.addSubview(statusLabel)

        spinner = NSProgressIndicator(frame: NSRect(x: 20, y: 12, width: 320, height: 6))
        spinner.style = .bar
        spinner.isIndeterminate = true
        spinner.startAnimation(nil)
        container.addSubview(spinner)

        window.contentView = container
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func setStatus(_ text: String) {
        statusLabel.stringValue = text
    }

    func close() {
        spinner.stopAnimation(nil)
        window.close()
    }
}
