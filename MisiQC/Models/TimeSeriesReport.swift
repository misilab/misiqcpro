import Foundation

/// A single per-frame signalstats sample collected by the analysis pipeline.
/// Lightweight POD so that storing thousands of these in memory stays cheap.
struct TimeSeriesPoint: Hashable {
    var pts: Double            // pts_time in seconds
    var yAvg: Double = 0
    var yMin: Int = 0
    var yMax: Int = 0
    var brng: Double = 0       // proportion of OOR pixels for this frame, 0…1
    var tout: Double = 0       // temporal outliers proportion, 0…1
    var vrep: Double = 0       // vertical repetition proportion, 0…1
}

/// Aggregated per-frame time series produced during analysis. Drives the
/// timeline chart and the per-frame CSV export.
struct TimeSeriesReport: Hashable {
    var points: [TimeSeriesPoint] = []
    var durationSec: Double = 0
    var bitDepth: Int = 8
    /// Inverse of `sampleEvery` used by ffmpeg (e.g. 5 = every 5th frame).
    var samplingStride: Int = 5
}
