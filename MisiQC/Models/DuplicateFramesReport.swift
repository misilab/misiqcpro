import Foundation

/// Compares the input frame count (from ffprobe) with the number of frames
/// kept after `mpdecimate` to estimate how many duplicate/redundant frames
/// the file contains. A high ratio often signals a botched frame-rate
/// conversion (29.97 → 25, 3:2 pulldown leftover) or stalled material.
struct DuplicateFramesReport: Hashable {
    var inputFrameCount: Int
    var keptFrameCount: Int

    var duplicateFrameCount: Int {
        max(0, inputFrameCount - keptFrameCount)
    }

    var duplicateRatio: Double {
        guard inputFrameCount > 0 else { return 0 }
        return Double(duplicateFrameCount) / Double(inputFrameCount)
    }
}
