import AppKit
import Combine

/// Selector explicit Dark/Light/System, independent de setarea macOS
/// (2026-08-27, cerință Cristi) — port 1:1 al ThemeManager.swift
/// (MediaFlow Monitor, vezi CLAUDE.md Partea 1, Regula 18).
enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "Sistem"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil // nil = urmează setarea sistemului
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    private static let key = "gdcvault_app_theme"

    @Published var current: AppTheme {
        didSet { apply() }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.key)
        current = saved.flatMap(AppTheme.init(rawValue:)) ?? .system
        apply()
    }

    func set(_ theme: AppTheme) {
        UserDefaults.standard.set(theme.rawValue, forKey: Self.key)
        current = theme
    }

    private func apply() {
        NSApp.appearance = current.nsAppearance
    }
}
