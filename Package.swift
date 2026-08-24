// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "GDCVault",
    platforms: [.macOS(.v14)],
    targets: [
        // Model + licentiere + Keychain, fara UI - la fel ca separarea
        // Core/Client din GDCPluginManager (vezi Package.swift de acolo).
        // LicenseCore.swift/MachineID.swift sunt copiate BYTE-FOR-BYTE din
        // gdc-plugin-manager-catalog-vendor: aceeasi cheie publica, deci
        // orice cod generat deja din Furnizor pentru id-ul "gdc-vault"
        // functioneaza aici neschimbat.
        .target(
            name: "GDCVaultCore",
            path: "Sources/GDCVaultCore"
        ),
        .executableTarget(
            name: "GDCVault",
            dependencies: ["GDCVaultCore"],
            path: "Sources/GDCVault"
        )
    ]
)
