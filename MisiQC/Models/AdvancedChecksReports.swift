import Foundation

// MARK: - GOP structure

/// Result of parsing the first N video frames to determine GOP behaviour.
struct GOPReport: Hashable {
    var averageGopLength: Double = 0
    var maxGopLength: Int = 0
    var iFrameCount: Int = 0
    var totalFramesAnalyzed: Int = 0
    /// `true` when every GOP ends with a non-B frame (= closed). `nil` when
    /// not enough data to decide.
    var closedGop: Bool?
}

// MARK: - Audio phase (L/R correlation)

/// Aggregate stereo phase correlation. `1` = perfectly correlated (mono safe),
/// `0` = decorrelated, `-1` = phase inverted (cancels in mono down-mix).
struct AudioPhaseReport: Hashable {
    var meanPhase: Double = 0
    var minPhase: Double = 1
    var maxPhase: Double = 1
    /// Ratio of measured frames whose phase fell below zero.
    var antiPhaseRatio: Double = 0
    var sourceLabel: String = ""
}

// MARK: - Interlace detection

/// Counts produced by the ffmpeg `idet` filter. The "multi-frame" form is
/// the more reliable verdict.
struct InterlaceReport: Hashable {
    var tff: Int = 0
    var bff: Int = 0
    var progressive: Int = 0
    var undetermined: Int = 0

    var total: Int { tff + bff + progressive + undetermined }

    /// Dominant verdict among TFF / BFF / progressive.
    var dominant: String {
        let buckets: [(String, Int)] = [
            ("tt", tff), ("bb", bff), ("progressive", progressive), ("undetermined", undetermined)
        ]
        return buckets.max { $0.1 < $1.1 }?.0 ?? "undetermined"
    }
}

// MARK: - Letterbox / pillarbox detection

struct CropBox: Hashable { var w: Int; var h: Int; var x: Int; var y: Int }

struct CropReport: Hashable {
    var recommended: CropBox
    var inputWidth: Int
    var inputHeight: Int

    var hasLetterbox: Bool {
        recommended.y > 2 || (recommended.h < inputHeight - 4)
    }
    var hasPillarbox: Bool {
        recommended.x > 2 || (recommended.w < inputWidth - 4)
    }
    var isFullFrame: Bool { !hasLetterbox && !hasPillarbox }
}

// MARK: - Signal-range strictness preset

/// Preset bundles for the signal-range verdict thresholds.
/// Each case carries 6 thresholds (pass/warn × mean/peak/Y excursion in %).
enum SignalStrictness: String, CaseIterable, Codable, Identifiable {
    /// Raw values preserved to keep user prefs across renames. The first case
    /// (strictBroadcast) is renamed to "Pro broadcast" in UI, and `ebuR103`
    /// to "Premium broadcast" — a new `ebuR103Official` carries the actual
    /// EBU R103 norm thresholds.
    case strictBroadcast
    case ebuR103
    case ebuR103Official
    case permissiveOTT

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .strictBroadcast:  return "Pro broadcast (France TV, ARTE, BBC)"
        case .ebuR103:          return "Premium broadcast (recommandé)"
        case .ebuR103Official:  return "EBU R103 v3.0 (norme officielle)"
        case .permissiveOTT:    return "Permissif OTT (Netflix, Amazon…)"
        }
    }

    var summary: String {
        switch self {
        case .strictBroadcast:
            return "Calibré sur les QC internes des diffuseurs français. Refuse tout débordement audible."
        case .ebuR103:
            return "Tolère les overshoots codec, refuse les vrais grading hors plage. Mode par défaut."
        case .ebuR103Official:
            return "Norme EBU R103 v3.0 papier — plus permissif : accepte jusqu'à 1% pixels OOR en moyenne."
        case .permissiveOTT:
            return "Pour livraisons streaming peu regardantes (Netflix, Amazon, Disney+)."
        }
    }

    struct Thresholds {
        var passMean: Double, passPeak: Double, passY: Double
        var warnMean: Double, warnPeak: Double, warnY: Double
    }

    /// Y excursion is the absolute single-pixel worst excursion (very sensitive
    /// to IDCT ringing), so its thresholds are wider than pixel-level BRNG.
    var thresholds: Thresholds {
        switch self {
        case .strictBroadcast:
            // France TV / ARTE / BBC internal QC — zero tolerance.
            return .init(passMean: 0.005, passPeak: 0.1, passY: 1.0,
                         warnMean: 0.1,   warnPeak: 0.5, warnY: 2.0)
        case .ebuR103:
            // "Premium broadcast" — calibré sur la pratique pro réelle.
            return .init(passMean: 0.01,  passPeak: 0.5, passY: 3.0,
                         warnMean: 0.5,   warnPeak: 2.0, warnY: 4.0)
        case .ebuR103Official:
            // EBU R103 v3.0 papier — "Permitted" ≤ 1%, "Tolerated" ≤ 2% mean.
            return .init(passMean: 1.0,   passPeak: 5.0, passY: 4.0,
                         warnMean: 2.0,   warnPeak: 5.0, warnY: 6.0)
        case .permissiveOTT:
            return .init(passMean: 0.05,  passPeak: 1.0, passY: 4.0,
                         warnMean: 1.0,   warnPeak: 3.0, warnY: 6.0)
        }
    }
}

// MARK: - PSE / Photosensitivity (Harding-inspired)

/// Approximation of a photosensitive-epilepsy risk check. Real Harding
/// certification requires regulated equipment and considers spatial area,
/// colour content and accumulated risk; we look only at global luminance
/// transitions, which catches the most obvious risky sequences (strobing,
/// hard cuts to white, flashing logos).
struct PSEReport: Hashable {
    /// Number of luminance-change events that exceeded the detection threshold.
    var flashEventCount: Int = 0
    /// Highest density of flashes seen in any 1-second window.
    var peakFlashesPerSec: Double = 0
    /// Time ranges where the flash rate stayed above 3/sec — the regulatory
    /// "alarm" threshold above which Harding rates the content "harmful".
    var riskySegments: [TimeRange] = []
    /// Frames effectively analysed by signalstats.
    var totalFramesAnalyzed: Int = 0
    /// Detection threshold as a fraction of the full luma range (0…1).
    var thresholdFraction: Double = 0
}

// MARK: - Audio statistics (DC offset / peak / RMS)

struct AudioStatsReport: Hashable {
    var overallDCOffset: Double = 0
    var peakLevelDB: Double?
    var rmsLevelDB: Double?
    var perChannelDCOffset: [Double] = []

    /// DC offset is in -1…1 range; > 1% (= 0.01) is typically considered
    /// problematic for clean broadcast audio.
    var dcOffsetPct: Double { abs(overallDCOffset) * 100 }
}
