import SwiftUI

/// Setare explicita "Marime Text" (Regula 24, CLAUDE.md) - lipsea din
/// GDCVault (adaugata standard abia dupa ultima actualizare a acestui
/// repo). Port 1:1 al `TextScalePreference`/`TextScaleManager` din
/// gdc-plugin-manager-catalog-vendor/Sources/GDCPluginManagerCore/AppTheme.swift
/// - infrastructura NATIVA de accesibilitate SwiftUI (`dynamicTypeSize`),
/// nu un multiplicator brut de font.
enum TextScalePreference: String, CaseIterable, Identifiable {
    case small, normal, large, xlarge

    var id: String { rawValue }

    var label: String {
        switch self {
        case .small: return "Mic"
        case .normal: return "Normal"
        case .large: return "Mare"
        case .xlarge: return "Foarte mare"
        }
    }

    var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .small: return .small
        case .normal: return .large
        case .large: return .xLarge
        case .xlarge: return .xxxLarge
        }
    }
}

final class TextScaleManager: ObservableObject {
    static let shared = TextScaleManager()

    private static let key = "GDCVault.textScale"

    @Published var current: TextScalePreference {
        didSet {
            guard current != oldValue else { return }
            UserDefaults.standard.set(current.rawValue, forKey: Self.key)
        }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.key)
        current = saved.flatMap(TextScalePreference.init(rawValue:)) ?? .normal
    }
}
