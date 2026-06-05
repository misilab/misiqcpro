import Foundation

/// Runs `ffprobe` against a media file and returns a decoded `MediaProbe`.
enum FFprobeRunner {
    static func probe(url: URL) async throws -> MediaProbe {
        let binary = try BinaryLocator.ffprobeURL()
        let result = try await ProcessRunner.run(
            executable: binary,
            arguments: [
                "-v", "error",
                "-show_format",
                "-show_streams",
                "-print_format", "json",
                url.path
            ]
        )
        guard let data = result.stdout.data(using: .utf8) else {
            throw NSError(domain: "FFprobeRunner", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Sortie ffprobe vide ou non UTF-8."])
        }
        let decoder = JSONDecoder()
        return try decoder.decode(MediaProbe.self, from: data)
    }

    /// Probes the first ~30s for packet-level side data (AFD flags live in MPEG-2
    /// user_data and aren't always picked up by `-show_streams`).
    static func packetSideDataDump(url: URL) async throws -> String {
        let binary = try BinaryLocator.ffprobeURL()
        let result = try await ProcessRunner.run(
            executable: binary,
            arguments: [
                "-v", "error",
                "-read_intervals", "%+30",
                "-select_streams", "v:0",
                "-show_packets",
                "-show_data_hash", "crc32",
                "-show_entries", "packet=pts_time:side_data=type,active_format",
                "-of", "json",
                url.path
            ],
            throwOnNonZeroExit: false
        )
        return result.stdout
    }

    /// Reads the first frame's SMPTE timecode (when available) using ffprobe's
    /// frame inspection. Returns nil if no `timecode` tag is found.
    static func firstFrameTimecode(url: URL) async throws -> String? {
        let binary = try BinaryLocator.ffprobeURL()
        let result = try await ProcessRunner.run(
            executable: binary,
            arguments: [
                "-v", "error",
                "-select_streams", "v:0",
                "-show_entries", "stream_tags=timecode:format_tags=timecode",
                "-of", "default=noprint_wrappers=1:nokey=0",
                url.path
            ],
            throwOnNonZeroExit: false
        )
        for line in result.stdout.split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1).map { String($0) }
            if parts.count == 2, parts[0].hasSuffix("timecode") {
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                if !value.isEmpty, value != "N/A" { return value }
            }
        }
        return nil
    }
}
