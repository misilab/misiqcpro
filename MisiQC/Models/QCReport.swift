import Foundation

/// Final aggregated report shown to the user and exported to PDF.
struct QCReport: Identifiable, Hashable {
    let id = UUID()
    var fileURL: URL
    var spec: ChannelSpec
    var analyzedAt: Date
    var probe: MediaProbe?
    var loudness: [LoudnessReport]
    var content: ContentReport
    var checks: [Check]
    /// Locale used when the report was built — used by the PDF renderer to
    /// keep section names / verdict consistent with the on-screen labels.
    var locale: AppLocale = .fr

    /// Overall verdict: fail if any check fails, warning if any warns, else pass.
    var verdict: CheckStatus {
        if checks.contains(where: { $0.status == .fail }) { return .fail }
        if checks.contains(where: { $0.status == .warning }) { return .warning }
        return .pass
    }

    var passCount: Int { checks.filter { $0.status == .pass }.count }
    var warningCount: Int { checks.filter { $0.status == .warning }.count }
    var failCount: Int { checks.filter { $0.status == .fail }.count }
}

enum CheckCategory: String, Codable, CaseIterable {
    case container, video, audio, loudness, structure

    func localizedName(_ locale: AppLocale) -> String {
        let key: L10n.Key
        switch self {
        case .container: key = .catContainer
        case .video:     key = .catVideo
        case .audio:     key = .catAudio
        case .loudness:  key = .catLoudness
        case .structure: key = .catStructure
        }
        return L10n.t(key, locale)
    }
}

enum CheckStatus: String, Codable {
    case pass
    case warning
    case fail

    var symbolName: String {
        switch self {
        case .pass: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .fail: return "xmark.octagon.fill"
        }
    }

    var displayName: String {
        switch self {
        case .pass: return "Conforme"
        case .warning: return "Avertissement"
        case .fail: return "Non conforme"
        }
    }

    func localizedName(_ locale: AppLocale) -> String {
        let key: L10n.Key
        switch self {
        case .pass: key = .verdictPass
        case .warning: key = .verdictWarn
        case .fail: key = .verdictFail
        }
        return L10n.t(key, locale)
    }
}

struct Check: Identifiable, Hashable {
    let id = UUID()
    var category: CheckCategory
    var label: String
    var expected: String
    var actual: String
    var status: CheckStatus
    var detail: String?
}
