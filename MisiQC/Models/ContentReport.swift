import Foundation

/// Results of content-level analysis (black frames, silence, structural checks).
struct ContentReport: Hashable {
    var blackSegments: [TimeRange] = []
    var silenceSegments: [SilenceSegment] = []
    /// Start time code of the first useful frame, when readable.
    var firstFrameTimecode: String?
    /// Total file duration in seconds, from container metadata.
    var totalDurationSec: Double?
    /// Luma excursion analysis (infra-black / super-white).
    var signalStats: SignalStatsReport?
    /// Frozen / still video segments detected with `freezedetect`.
    var frozenSegments: [TimeRange] = []
    /// Duplicate / redundant frame count vs the input stream.
    var duplicateFrames: DuplicateFramesReport?
    /// Stuck / dead pixel estimate from a sparse temporal sampling.
    var deadPixels: DeadPixelReport?
    /// GOP structure (real, from packet parsing).
    var gop: GOPReport?
    /// Interlace verdict from ffmpeg `idet`.
    var interlace: InterlaceReport?
    /// Letterbox / pillarbox detection result.
    var crop: CropReport?
    /// L/R phase correlation per analysed stereo pair.
    var phaseReports: [AudioPhaseReport] = []
    /// Audio statistics — DC offset, peak, RMS.
    var audioStats: AudioStatsReport?
    /// Approximated photosensitive epilepsy risk (Harding-inspired).
    var pse: PSEReport?
    /// Per-frame metrics collected during the signal-range pass — drives the
    /// timeline chart and CSV export.
    var timeSeries: TimeSeriesReport?
    /// Color bars + 1 kHz tone leader analysis (first 30 s).
    var leader: LeaderReport?
    /// Embedded subtitles / closed captions presence.
    var subtitles: SubtitlesReport?
    /// AFD (Active Format Description) flag.
    var afd: AFDReport?
    /// HDR static metadata (Mastering Display + MaxCLL/MaxFALL).
    var hdr: HDRMetadataReport?
    /// Post-roll trailing black / hard cut detection.
    var postRoll: PostRollReport?
    /// Audio pop / click detection.
    var audioPops: AudioPopsReport?
}

struct TimeRange: Hashable {
    var startSec: Double
    var endSec: Double
    var durationSec: Double { endSec - startSec }
}

struct SilenceSegment: Hashable {
    /// 0-based track index this silence was measured on.
    var trackIndex: Int
    var range: TimeRange
}
