import Foundation

/// Aggregate result of the `signalstats` filter: the worst luma min and max
/// values seen across the sampled frames, used to detect infra-black (signal
/// going below the legal "0%") and super-white (above legal "100%").
struct SignalStatsReport: Hashable {
    /// Lowest YMIN value seen across all sampled frames.
    var minYMin: Int?
    /// Highest YMAX value seen across all sampled frames.
    var maxYMax: Int?
    /// Number of frames sampled. Useful for diagnostics.
    var framesSampled: Int = 0
    /// Sub-set of `framesSampled` whose YMIN dipped below the legal floor.
    var framesWithInfraBlack: Int = 0
    /// Sub-set of `framesSampled` whose YMAX rose above the legal ceiling.
    var framesWithSuperWhite: Int = 0
    /// Pixel-level metric: mean ratio of out-of-broadcast-range pixels per
    /// frame (0…1). This is what pro QC tools like Baton/Cerify report. Far
    /// more meaningful than the binary "frame contains ≥ 1 illegal pixel".
    var meanPixelBRNG: Double = 0
    /// Worst single-frame BRNG (0…1). Highlights short spikes of bad content.
    var peakPixelBRNG: Double = 0
    /// Inferred bit depth (8, 10, 12). Used to interpret the codec-native range.
    var bitDepth: Int = 8

    /// Worst-case affected frame count (union of infra-black and super-white).
    var framesOutOfRange: Int { max(framesWithInfraBlack, framesWithSuperWhite) }

    /// Ratio of affected frames over the sampled set, 0…1.
    var outOfRangeRatio: Double {
        guard framesSampled > 0 else { return 0 }
        return Double(framesOutOfRange) / Double(framesSampled)
    }

    /// Legal "video range" boundaries for the given bit depth.
    /// (Source: ITU-R BT.709 / EBU R103 narrow range.)
    static func legalRange(forBitDepth d: Int) -> (low: Int, high: Int) {
        switch d {
        case 12: return (256, 3760)
        case 10: return (64, 940)
        default: return (16, 235) // 8-bit
        }
    }

    /// Codec-native maximum value for the bit depth (used as a sanity ceiling).
    static func codecMax(forBitDepth d: Int) -> Int {
        (1 << d) - 1
    }

    /// `true` when both luma extremes fall within the legal broadcast range.
    var isInLegalRange: Bool {
        let range = Self.legalRange(forBitDepth: bitDepth)
        let okMin = (minYMin ?? range.low) >= range.low
        let okMax = (maxYMax ?? range.high) <= range.high
        return okMin && okMax
    }

    var infraBlack: Bool {
        guard let m = minYMin else { return false }
        return m < Self.legalRange(forBitDepth: bitDepth).low
    }

    var superWhite: Bool {
        guard let m = maxYMax else { return false }
        return m > Self.legalRange(forBitDepth: bitDepth).high
    }

    /// Render the measured values as "0%–100%" percentage strings, so the report
    /// shows e.g. "-3%–105%" when the signal escapes the legal window.
    func percentString() -> String {
        let range = Self.legalRange(forBitDepth: bitDepth)
        let span = Double(range.high - range.low)
        let minPct = minYMin.map { (Double($0) - Double(range.low)) / span * 100 }
        let maxPct = maxYMax.map { (Double($0) - Double(range.low)) / span * 100 }
        let lo = minPct.map { String(format: "%.0f%%", $0) } ?? "—"
        let hi = maxPct.map { String(format: "%.0f%%", $0) } ?? "—"
        return "\(lo) → \(hi)"
    }
}
