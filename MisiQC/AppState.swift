import Foundation
import Observation

/// Central, observable state of the app. Owns the selected spec, the file under
/// analysis, the pipeline stage, the produced report and user preferences
/// (language, default profile, detection thresholds).
@Observable
@MainActor
final class AppState {
    // MARK: - Session state

    var availableSpecs: [ChannelSpec] = []
    var selectedSpec: ChannelSpec?
    var selectedVariant: VersionVariant = .vfOnly
    var droppedFile: URL?

    var isAnalyzing: Bool = false
    var currentStage: QCEngine.Stage?
    var lastReport: QCReport?
    var errorMessage: String?

    // MARK: - Licence

    let license = LicenseService()

    // MARK: - Persisted preferences

    var locale: AppLocale = .fr {
        didSet { UserDefaults.standard.set(locale.rawValue, forKey: Self.kLocale) }
    }
    var defaultProfileID: String = "francetv" {
        didSet { UserDefaults.standard.set(defaultProfileID, forKey: Self.kDefaultProfile) }
    }
    var defaultVariant: VersionVariant = .vfOnly {
        didSet { UserDefaults.standard.set(defaultVariant.rawValue, forKey: Self.kDefaultVariant) }
    }
    var blackThresholdSec: Double = 1.0 {
        didSet { UserDefaults.standard.set(blackThresholdSec, forKey: Self.kBlackThr) }
    }
    var silenceThresholdSec: Double = 1.0 {
        didSet { UserDefaults.standard.set(silenceThresholdSec, forKey: Self.kSilenceThr) }
    }
    var signalStrictness: SignalStrictness = .ebuR103 {
        didSet { UserDefaults.standard.set(signalStrictness.rawValue, forKey: Self.kStrictness) }
    }

    // MARK: - Init

    init() {
        availableSpecs = SpecRepository.loadAll()

        let savedLocale = UserDefaults.standard.string(forKey: Self.kLocale)
            .flatMap(AppLocale.init(rawValue:)) ?? .fr
        self.locale = savedLocale

        let savedProfile = UserDefaults.standard.string(forKey: Self.kDefaultProfile)
            ?? availableSpecs.first?.id ?? "francetv"
        self.defaultProfileID = savedProfile

        let savedVariant = UserDefaults.standard.string(forKey: Self.kDefaultVariant)
            .flatMap(VersionVariant.init(rawValue:)) ?? .vfOnly
        self.defaultVariant = savedVariant

        let savedBlack = UserDefaults.standard.object(forKey: Self.kBlackThr) as? Double ?? 1.0
        self.blackThresholdSec = savedBlack
        let savedSilence = UserDefaults.standard.object(forKey: Self.kSilenceThr) as? Double ?? 1.0
        self.silenceThresholdSec = savedSilence

        let savedStrict = UserDefaults.standard.string(forKey: Self.kStrictness)
            .flatMap(SignalStrictness.init(rawValue:)) ?? .ebuR103
        self.signalStrictness = savedStrict

        // Pick the default profile if present, otherwise first available.
        self.selectedSpec = availableSpecs.first { $0.id == savedProfile }
            ?? availableSpecs.first
        self.selectedVariant = savedVariant
    }

    // MARK: - Computed

    /// Variants exposed for the currently selected spec. Falls back to `[.vfOnly]`
    /// when the spec doesn't declare a channel mapping (typical of OTT platforms
    /// that deliver one language per CPL).
    var availableVariants: [VersionVariant] {
        guard let spec = selectedSpec else { return [.vfOnly] }
        let order: [VersionVariant] = [.vfOnly, .vfVO, .vfAD, .vfVOAD]
        let declared = Set(spec.audio.availableVariants)
        let filtered = order.filter { declared.contains($0) }
        return filtered.isEmpty ? [.vfOnly] : filtered
    }

    func reset() {
        droppedFile = nil
        lastReport = nil
        errorMessage = nil
        currentStage = nil
        isAnalyzing = false
    }

    func resetAllPreferences() {
        locale = .fr
        defaultProfileID = availableSpecs.first?.id ?? "francetv"
        defaultVariant = .vfOnly
        blackThresholdSec = 1.0
        silenceThresholdSec = 1.0
        signalStrictness = .ebuR103
    }

    /// Short-hand to localise a key with the current locale.
    func t(_ key: L10n.Key) -> String { L10n.t(key, locale) }

    func analyze(file: URL) async {
        guard let spec = selectedSpec else {
            errorMessage = t(.errorNoProfileSelected)
            return
        }
        isAnalyzing = true
        lastReport = nil
        errorMessage = nil
        droppedFile = file
        currentStage = .probing

        do {
            let report = try await QCEngine.analyze(
                file: file,
                spec: spec,
                versionVariant: selectedVariant,
                strictness: signalStrictness,
                blackMinDurationSec: blackThresholdSec,
                silenceMinDurationSec: silenceThresholdSec,
                locale: locale,
                progress: { stage in
                    Task { @MainActor [weak self] in
                        self?.currentStage = stage
                    }
                }
            )
            lastReport = report
        } catch {
            errorMessage = error.localizedDescription
        }
        isAnalyzing = false
        currentStage = nil
    }

    // MARK: - UserDefaults keys

    private static let kLocale = "app.locale"
    private static let kDefaultProfile = "app.defaultProfile"
    private static let kDefaultVariant = "app.defaultVariant"
    private static let kBlackThr = "app.blackThresholdSec"
    private static let kSilenceThr = "app.silenceThresholdSec"
    private static let kStrictness = "app.signalStrictness"
}
