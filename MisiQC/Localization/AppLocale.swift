import Foundation

/// Locales offered in Settings. Persisted in UserDefaults as the raw value.
enum AppLocale: String, CaseIterable, Identifiable, Codable {
    case fr
    case en
    case es

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fr: return "Français"
        case .en: return "English"
        case .es: return "Español"
        }
    }

    var flagEmoji: String {
        switch self {
        case .fr: return "🇫🇷"
        case .en: return "🇬🇧"
        case .es: return "🇪🇸"
        }
    }

    var shortLabel: String {
        switch self {
        case .fr: return "FR"
        case .en: return "EN"
        case .es: return "ES"
        }
    }
}
