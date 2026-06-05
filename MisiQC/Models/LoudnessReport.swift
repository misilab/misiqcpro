import Foundation

/// Output of an EBU R128 measurement via ffmpeg's `ebur128` filter.
struct LoudnessReport: Hashable {
    /// Identifier of the audio source measured (e.g. "VF Stereo (T1+T2)").
    var sourceLabel: String

    /// Integrated loudness in LUFS.
    var integratedLUFS: Double?
    /// True peak in dBTP.
    var truePeakDBTP: Double?
    /// Loudness range in LU.
    var loudnessRangeLU: Double?
    /// Threshold the measurement used (informational, LUFS).
    var thresholdLUFS: Double?

    var hasMeasurement: Bool {
        integratedLUFS != nil || truePeakDBTP != nil || loudnessRangeLU != nil
    }
}
