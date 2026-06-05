import Foundation
import AVFoundation
import CoreGraphics

/// Detects stuck / dead pixels by sampling N evenly-spaced frames through the
/// programme and walking a sparse pixel grid. A pixel position whose RGB
/// value never changes across the whole sample is flagged.
///
/// This is intentionally lightweight (sparse grid, only a dozen frames) so
/// it stays well under a second even on UHD masters.
enum DeadPixelDetector {

    static func detect(
        url: URL,
        sampleCount: Int = 12,
        pixelStride: Int = 8
    ) async throws -> DeadPixelReport {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        guard duration > 0 else { return .empty }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        // Skip first/last 5% — programme often starts/ends with flat colour
        // (countdown, logo, fade out) that would mask real stuck pixels.
        let head = duration * 0.05
        let span = duration * 0.9
        let times: [CMTime] = (0..<sampleCount).map { idx in
            let t = head + span * Double(idx) / Double(max(1, sampleCount - 1))
            return CMTime(seconds: t, preferredTimescale: 600)
        }

        var samples: [(width: Int, height: Int, data: [UInt8])] = []
        for time in times {
            do {
                let cg = try await generator.image(at: time).image
                if let buf = pixelBuffer(from: cg) {
                    samples.append(buf)
                }
            } catch {
                // Skip individual failures (seek error, etc.)
            }
        }
        guard let first = samples.first, samples.count >= 4 else {
            return .empty
        }

        let w = first.width
        let h = first.height
        let bytesPerRow = w * 4

        var stuck = 0
        var sampledPixels = 0

        for y in stride(from: 0, to: h, by: pixelStride) {
            for x in stride(from: 0, to: w, by: pixelStride) {
                sampledPixels += 1
                let offset = y * bytesPerRow + x * 4
                let firstR = first.data[offset]
                let firstG = first.data[offset + 1]
                let firstB = first.data[offset + 2]

                var allEqual = true
                for sample in samples.dropFirst() {
                    if offset + 2 >= sample.data.count { allEqual = false; break }
                    if sample.data[offset]     != firstR ||
                       sample.data[offset + 1] != firstG ||
                       sample.data[offset + 2] != firstB {
                        allEqual = false
                        break
                    }
                }
                if allEqual { stuck += 1 }
            }
        }
        return DeadPixelReport(
            stuckCount: stuck,
            sampledPixels: sampledPixels,
            sampleImagesCount: samples.count
        )
    }

    /// Draws a CGImage into an 8-bit RGBA bitmap context and returns the raw
    /// pixel bytes (RGBA, premultiplied last) plus the dimensions.
    private static func pixelBuffer(from cgImage: CGImage)
    -> (width: Int, height: Int, data: [UInt8])? {
        let w = cgImage.width
        let h = cgImage.height
        var data = [UInt8](repeating: 0, count: w * h * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo: UInt32 = CGImageAlphaInfo.premultipliedLast.rawValue
        let ok: Bool = data.withUnsafeMutableBufferPointer { ptr -> Bool in
            guard let ctx = CGContext(
                data: ptr.baseAddress,
                width: w, height: h,
                bitsPerComponent: 8,
                bytesPerRow: w * 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else { return false }
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        return ok ? (w, h, data) : nil
    }
}
