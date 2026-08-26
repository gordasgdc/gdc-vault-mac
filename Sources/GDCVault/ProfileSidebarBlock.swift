import SwiftUI

/// Bloc "Profil Utilizator" în sidebar — port 1:1 al ProfileSidebarBlock.swift
/// din GDC Plugin Manager (vezi CLAUDE.md, Partea 1, Regula 12). Arată
/// Nume (sau „Anonim"), Email și Machine ID, editabil prin click.
struct ProfileSidebarBlock: View {
    @ObservedObject private var profile = UserProfileStore.shared
    @State private var showEditor = false
    @State private var editName = ""
    @State private var editEmail = ""
    @State private var justCopiedID = false

    var body: some View {
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
                Text(profile.machineID)
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
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
