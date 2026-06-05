import Foundation

/// Top-level ffprobe JSON output, decoded into a usable shape.
struct MediaProbe: Codable, Hashable {
    var format: ProbeFormat
    var streams: [ProbeStream]

    var videoStreams: [ProbeStream] { streams.filter { $0.codec_type == "video" } }
    var audioStreams: [ProbeStream] { streams.filter { $0.codec_type == "audio" } }
    var subtitleStreams: [ProbeStream] { streams.filter { $0.codec_type == "subtitle" } }
    var dataStreams: [ProbeStream] { streams.filter { $0.codec_type == "data" } }
}

struct ProbeFormat: Codable, Hashable {
    var filename: String?
    var nb_streams: Int?
    var format_name: String?
    var format_long_name: String?
    var duration: String?
    var size: String?
    var bit_rate: String?
    var tags: [String: String]?

    var durationSeconds: Double? { duration.flatMap(Double.init) }
    var bitRateBps: Double? { bit_rate.flatMap(Double.init) }
}

struct ProbeStream: Codable, Hashable {
    var index: Int
    var codec_type: String?     // "video" / "audio"
    var codec_name: String?     // "mpeg2video" / "pcm_s24le"
    var codec_long_name: String?
    var profile: String?        // "4:2:2"
    var level: Int?
    var width: Int?
    var height: Int?
    var pix_fmt: String?
    var sample_aspect_ratio: String?   // "1:1", "16:11"…
    var display_aspect_ratio: String?  // "16:9", "4:3"…
    var color_space: String?       // matrix coefficients ("bt709", "bt2020nc"…)
    var color_primaries: String?   // ("bt709", "bt2020", "smpte170m"…)
    var color_transfer: String?    // EOTF/gamma ("bt709", "smpte2084" = PQ, "arib-std-b67" = HLG…)
    var color_range: String?       // "tv" (narrow/legal) or "pc" (full)
    var field_order: String?       // "tt", "bb", "progressive"
    var r_frame_rate: String?   // "25/1"
    var avg_frame_rate: String?
    var time_base: String?
    var start_time: String?
    var duration: String?
    var bit_rate: String?
    var nb_frames: String?

    // Audio
    var sample_fmt: String?
    var sample_rate: String?
    var channels: Int?
    var channel_layout: String?
    var bits_per_raw_sample: String?
    var bits_per_sample: Int?

    var tags: [String: String]?
    var side_data_list: [ProbeSideData]?

    var bitRateBps: Double? { bit_rate.flatMap(Double.init) }
    var sampleRateHz: Int? { sample_rate.flatMap(Int.init) }
    var bitDepth: Int? {
        if let b = bits_per_raw_sample, let v = Int(b), v > 0 { return v }
        if let v = bits_per_sample, v > 0 { return v }
        return nil
    }

    /// Frame rate parsed as rational; falls back to avg if r_frame_rate absent.
    var rationalRate: RationalRate? {
        let candidate = r_frame_rate ?? avg_frame_rate
        guard let s = candidate else { return nil }
        let parts = s.split(separator: "/")
        guard parts.count == 2,
              let num = Int(parts[0]),
              let den = Int(parts[1]),
              den != 0 else { return nil }
        return RationalRate(num: num, den: den)
    }

    var resolution: Resolution? {
        if let w = width, let h = height { return Resolution(width: w, height: h) }
        return nil
    }

    /// Resolved color range: prefers `color_range`, falls back to pix_fmt suffix
    /// ("yuvjXXX" implies full range).
    var resolvedColorRange: String? {
        if let r = color_range, !r.isEmpty, r != "unknown" { return r }
        if let p = pix_fmt {
            if p.hasPrefix("yuvj") || p.hasPrefix("yuvaj") { return "pc" }
        }
        return nil
    }
}

/// Stream-level side data — ffprobe emits these for HDR metadata, AFD flags,
/// closed captions, mastering display info, etc.
struct ProbeSideData: Codable, Hashable {
    var side_data_type: String?
    // Mastering display metadata
    var red_x: String?
    var red_y: String?
    var green_x: String?
    var green_y: String?
    var blue_x: String?
    var blue_y: String?
    var white_point_x: String?
    var white_point_y: String?
    var min_luminance: String?
    var max_luminance: String?
    // Content light level
    var max_content: Int?
    var max_average: Int?
    // AFD
    var active_format: Int?
}
