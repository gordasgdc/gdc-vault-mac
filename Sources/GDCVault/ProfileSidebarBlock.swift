import SwiftUI
import GDCVaultCore

/// Bloc "Profil Utilizator" în sidebar — port 1:1 al ProfileSidebarBlock.swift
/// din GDC Plugin Manager (vezi CLAUDE.md, Partea 1, Regula 12). Arată
/// Nume (sau „Anonim"), Email, Machine ID (cu Copy rapid direct în panou —
/// nu doar în popover) și Status Licență/Serie sau buton de activare
/// (2026-08-27, cerință UX explicită).
struct ProfileSidebarBlock: View {
    @ObservedObject private var profile = UserProfileStore.shared
    @ObservedObject private var license = LicenseManager.shared
    var onActivateTapped: () -> Void = {}

    @State private var showEditor = false
    @State private var editName = ""
    @State private var editEmail = ""
    @State private var justCopiedID = false

    private var licenseStatusText: String {
        if license.isLicensed {
            return license.licenseExpiresAt == 0 ? "Licențiat (perpetuu)" : "Licențiat"
        }
        return license.isTrialActive ? "Probă — \(license.trialDaysRemaining)z rămase" : "Probă expirată"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button { showEditor = true } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Image(systemName: "person.circle")
                            .foregroundStyle(.secondary)
                        Text(profile.displayName)
                            .font(.system(size: 11))
                            .fontWeight(.medium)
                    }
                    if !profile.email.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text(profile.email)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 4) {
                Text(profile.machineID)
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                Spacer()
                Button {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(profile.machineID, forType: .string)
                    justCopiedID = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { justCopiedID = false }
                } label: {
                    Image(systemName: justCopiedID ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 9))
                }
                .buttonStyle(.plain)
                .help("Copiază Machine ID")
            }

            HStack(spacing: 4) {
                Image(systemName: license.isUnlocked ? "checkmark.seal.fill" : "exclamationmark.seal.fill")
                    .foregroundStyle(license.isUnlocked ? .green : .orange)
                    .font(.system(size: 9))
                if license.isLicensed, let code = license.savedLicenseCode, !code.isEmpty {
                    Text(code.count > 14 ? "…\(code.suffix(10))" : code)
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(licenseStatusText)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !license.isLicensed {
                    Button("Activează") { onActivateTapped() }
                        .buttonStyle(.plain)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .popover(isPresented: $showEditor) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Profil utilizator (opțional)").font(.headline)
                TextField("Nume", text: $editName).textFieldStyle(.roundedBorder)
                TextField("Email", text: $editEmail).textFieldStyle(.roundedBorder)
                HStack {
                    Text("ID mașină").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button(justCopiedID ? "Copiat." : "Copiază") {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(profile.machineID, forType: .string)
                        justCopiedID = true
                    }
                    .controlSize(.small)
                }
                Text(profile.machineID)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                HStack {
                    Spacer()
                    Button("OK") {
                        profile.save(name: editName, email: editEmail, sendTelemetry: true)
                        showEditor = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(16)
            .frame(width: 300)
            .onAppear {
                editName = profile.name
                editEmail = profile.email
            }
        }
    }
}
