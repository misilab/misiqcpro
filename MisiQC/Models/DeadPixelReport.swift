import Foundation

/// Result of the stuck-pixel detector. We sample N frames evenly through the
/// programme, walk a sparse grid of pixel positions and flag any whose RGB
/// value never changed across the whole sample set — those are dead / stuck
/// pixels (typical of older sensors or a faulty capture chain).
struct DeadPixelReport: Hashable {
    /// Pixel positions whose value was identical across all sampled frames.
    var stuckCount: Int = 0
    /// Total pixel positions inspected (grid). Used to express the ratio.
    var sampledPixels: Int = 0
    /// Number of source frames that were successfully sampled.
    var sampleImagesCount: Int = 0

    var stuckRatio: Double {
        guard sampledPixels > 0 else { return 0 }
        return Double(stuckCount) / Double(sampledPixels)
    }

    static let empty = DeadPixelReport()
}
