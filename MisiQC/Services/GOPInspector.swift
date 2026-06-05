import Foundation

/// Lightweight GOP analyser. Uses `ffprobe -show_frames` on the first N video
/// frames, then walks the `pict_type` sequence to compute the average / max
/// I-to-I distance and detect whether GOPs are closed.
enum GOPInspector {

    static func inspect(url: URL, maxFrames: Int = 300) async throws -> GOPReport {
        let binary = try BinaryLocator.ffprobeURL()
        let result = try await ProcessRunner.run(
            executable: binary,
            arguments: [
                "-v", "error",
                "-select_streams", "v:0",
                "-read_intervals", "%+\(maxFrames)",
                "-show_entries", "frame=pict_type,key_frame",
                "-of", "csv=p=0",
                url.path
            ],
            throwOnNonZeroExit: false
        )
        return parse(stdout: result.stdout)
    }

    static func parse(stdout: String) -> GOPReport {
        // Each line: "<key_frame>,<pict_type>" e.g. "1,I", "0,P", "0,B".
        var pictTypes: [Character] = []
        for raw in stdout.split(whereSeparator: { $0.isNewline }) {
            let line = String(raw)
            let parts = line.split(separator: ",")
            if parts.count >= 2, let t = parts[1].first {
                pictTypes.append(t)
            }
        }
        guard !pictTypes.isEmpty else { return GOPReport() }

        // Distances between consecutive I frames.
        var iIndices: [Int] = []
        for (idx, t) in pictTypes.enumerated() where t == "I" {
            iIndices.append(idx)
        }
        var report = GOPReport()
        report.totalFramesAnalyzed = pictTypes.count
        report.iFrameCount = iIndices.count

        guard iIndices.count >= 2 else {
            // Only one I frame visible — not enough to compute averages.
            if iIndices.count == 1, pictTypes.count > 1 {
                report.maxGopLength = pictTypes.count
                report.averageGopLength = Double(pictTypes.count)
            }
            return report
        }

        var distances: [Int] = []
        for k in 1..<iIndices.count {
            distances.append(iIndices[k] - iIndices[k - 1])
        }
        report.maxGopLength = distances.max() ?? 0
        report.averageGopLength = Double(distances.reduce(0, +)) / Double(distances.count)

        // Closed GOP: frame immediately before each (non-first) I-frame must NOT be a B-frame
        // (in a closed GOP the previous picture references the same GOP and is therefore P).
        var closed = true
        for k in 1..<iIndices.count {
            let prevIdx = iIndices[k] - 1
            if prevIdx >= 0, pictTypes[prevIdx] == "B" { closed = false; break }
        }
        report.closedGop = closed
        return report
    }
}
