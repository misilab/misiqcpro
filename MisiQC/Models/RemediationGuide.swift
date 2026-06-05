import Foundation

/// Identifies a class of QC failure for which we ship a fix recipe. Stable
/// keys — independent of UI labels and locale.
enum RemediationKey: String, Hashable, CaseIterable {
    case container
    case operationalPattern
    case videoCodec
    case videoProfile
    case resolution
    case framerate
    case interlace
    case videoBitrate
    case colorSpace
    case colorPrimaries
    case colorTransfer
    case colorRange
    case aspectRatio
    case gopStructure
    case signalRange
    case freeze
    case duplicates
    case stuckPixels
    case pse
    case audioChannels
    case audioCodec
    case audioBitDepth
    case audioSampleRate
    case audioPhase
    case dcOffset
    case loudnessIntegrated
    case loudnessTruePeak
    case loudnessLRA
    case timecodeStart
    case blackTooLong
    case silenceTooLong
    case framing
    case leaderBars
    case leaderTone
    case subtitlesMissing
    case afdMissing
    case hdrMetadataMissing
    case postRollMissing
    case audioPops
}

/// Trilingual string container — keeps each remediation card compact while
/// allowing us to ship FR / EN / ES side by side without three giant catalogs.
struct LocalizedString: Hashable {
    let fr: String
    let en: String
    let es: String

    func text(_ locale: AppLocale) -> String {
        switch locale {
        case .fr: return fr
        case .en: return en
        case .es: return es
        }
    }
}

/// Procedure to fix an issue inside a specific NLE / mastering app.
struct SoftwareFix: Hashable {
    let software: String              // proper name, not translated
    let steps: [LocalizedString]
}

/// Full remediation card shown in the export PDF for one failure type.
struct RemediationGuide: Hashable {
    let title: LocalizedString
    let cause: LocalizedString
    let actions: [SoftwareFix]
}

/// View resolved against a specific locale — what the renderer actually draws.
struct LocalizedRemediationGuide: Hashable {
    let title: String
    let cause: String
    let actions: [LocalizedSoftwareFix]

    init(_ guide: RemediationGuide, locale: AppLocale) {
        title = guide.title.text(locale)
        cause = guide.cause.text(locale)
        actions = guide.actions.map { fix in
            LocalizedSoftwareFix(
                software: fix.software,
                steps: fix.steps.map { $0.text(locale) }
            )
        }
    }
}

struct LocalizedSoftwareFix: Hashable {
    let software: String
    let steps: [String]
}
