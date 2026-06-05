import Foundation

// MARK: - 1. Bars + 1 kHz tone leader

/// Result of analysing the first ~30 seconds of the programme for the
/// presence of SMPTE/EBU color bars and a 1 kHz reference tone — the
/// standard PAD leader expected by most EU broadcasters.
struct LeaderReport: Hashable {
    var barsDetected: Bool = false
    /// 0…1 — combination of saturation level, luma stability and aspect of
    /// detected vertical bands.
    var barsConfidence: Double = 0
    var barsDurationSec: Double = 0

    var toneDetected: Bool = false
    /// Mean 1 kHz energy ratio over the analysed leader window — high = pure tone.
    var toneConfidence: Double = 0
    /// Mean dBFS level of the detected tone (broadcast reference = -18 dBFS).
    var toneLevelDBFS: Double?
}

// MARK: - 2. Embedded subtitles

struct SubtitlesReport: Hashable {
    /// Number of subtitle streams declared by ffprobe.
    var streamCount: Int = 0
    /// Stream-level codec names (e.g. "subrip", "dvd_subtitle", "dvb_subtitle",
    /// "eia_608", "mov_text").
    var formats: [String] = []
    /// True when at least one stream carries CEA-608 or CEA-708 captions.
    var hasClosedCaptions: Bool = false
    /// True when at least one DVB or teletext stream is present.
    var hasDVBOrTeletext: Bool = false
}

// MARK: - 3. AFD (Active Format Description, SMPTE 2016)

struct AFDReport: Hashable {
    var flagPresent: Bool = false
    var rawValue: Int?
    /// Human-readable AFD description from the spec table (e.g. "16:9 full frame",
    /// "16:9 letterbox 4:3 protected").
    var description: String?
}

// MARK: - 4. HDR static metadata

struct HDRMetadataReport: Hashable {
    var hasMasteringDisplay: Bool = false
    var hasContentLightLevel: Bool = false
    var maxCLL: Int?    // Max Content Light Level (cd/m²)
    var maxFALL: Int?   // Max Frame-Average Light Level (cd/m²)
    var masteringDisplayDescription: String?
    /// Whether the colour pipeline metadata is HDR-compatible (BT.2020 + PQ/HLG).
    var hasHDRColorPipeline: Bool = false
}

// MARK: - 5. Post-roll / trailing black

struct PostRollReport: Hashable {
    var hasTrailingBlack: Bool = false
    var trailingBlackDurationSec: Double = 0
    /// True if there's NO black at the very end (= hard cut on last image).
    var endsOnHardCut: Bool = false
}

// MARK: - 6. Audio pops / clicks

struct AudioPopsReport: Hashable {
    var jumpCount: Int = 0
    /// Worst level jump in dB across one short window.
    var biggestJumpDB: Double = 0
    var biggestJumpTimeSec: Double?
    /// All detected events (pts, dB jump) for the report detail.
    var events: [Event] = []

    struct Event: Hashable {
        var timeSec: Double
        var jumpDB: Double
    }
}
