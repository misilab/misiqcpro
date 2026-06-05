import Foundation

/// Produces the three reports that derive purely from probe metadata —
/// subtitles, HDR metadata and AFD. Kept separate so QCEngine reads tidy.
enum MetadataAnalyzer {

    // MARK: - Subtitles / closed captions

    static func subtitles(probe: MediaProbe) -> SubtitlesReport {
        var report = SubtitlesReport()
        let subs = probe.subtitleStreams
        report.streamCount = subs.count
        report.formats = subs.compactMap { $0.codec_name }

        let lowered = report.formats.map { $0.lowercased() }
        report.hasClosedCaptions = lowered.contains { name in
            name.contains("eia_608") || name.contains("eia_708") ||
            name.contains("cea608") || name.contains("cea708") ||
            name == "608" || name == "708"
        }
        report.hasDVBOrTeletext = lowered.contains { name in
            name.contains("dvb") || name.contains("teletext") ||
            name.contains("dvd_subtitle") || name.contains("pgs")
        }

        // Also detect CC carried in the video stream's side_data ("Closed Captions").
        for video in probe.videoStreams {
            for sd in video.side_data_list ?? [] {
                if let t = sd.side_data_type?.lowercased(),
                   t.contains("closed caption") || t.contains("cea") {
                    report.hasClosedCaptions = true
                }
            }
        }
        return report
    }

    // MARK: - HDR

    static func hdr(probe: MediaProbe) -> HDRMetadataReport {
        var report = HDRMetadataReport()
        guard let video = probe.videoStreams.first else { return report }

        // 1. Side data block presence.
        for sd in video.side_data_list ?? [] {
            let kind = sd.side_data_type?.lowercased() ?? ""
            if kind.contains("mastering display") {
                report.hasMasteringDisplay = true
                report.masteringDisplayDescription = formatMasteringDisplay(sd)
            }
            if kind.contains("content light level") {
                report.hasContentLightLevel = true
                report.maxCLL = sd.max_content
                report.maxFALL = sd.max_average
            }
        }

        // 2. Colour pipeline cue: BT.2020 + PQ or HLG.
        let primaries = video.color_primaries?.lowercased() ?? ""
        let transfer = video.color_transfer?.lowercased() ?? ""
        let isBT2020 = primaries.contains("2020")
        let isPQorHLG = transfer.contains("2084") || transfer.contains("smpte2084") ||
                        transfer.contains("arib-std-b67") || transfer.contains("hlg")
        report.hasHDRColorPipeline = isBT2020 && isPQorHLG
        return report
    }

    private static func formatMasteringDisplay(_ sd: ProbeSideData) -> String {
        // ffprobe encodes mastering display primaries as rational strings like
        // "13250/50000" — that's the chroma coordinate × 50000. We convert back
        // to 0…1 floats and emit a short readable form.
        func chroma(_ s: String?) -> Double? {
            guard let s = s else { return nil }
            if let v = Double(s) { return v }
            let parts = s.split(separator: "/").compactMap { Double($0) }
            guard parts.count == 2, parts[1] != 0 else { return nil }
            return parts[0] / parts[1]
        }
        func nits(_ s: String?) -> Double? {
            guard let s = s else { return nil }
            let parts = s.split(separator: "/").compactMap { Double($0) }
            if parts.count == 2, parts[1] != 0 { return parts[0] / parts[1] / 10_000 }
            return Double(s)
        }
        var pieces: [String] = []
        if let r = (chroma(sd.red_x), chroma(sd.red_y)) as? (Double, Double) {
            pieces.append(String(format: "R(%.3f,%.3f)", r.0, r.1))
        }
        if let g = (chroma(sd.green_x), chroma(sd.green_y)) as? (Double, Double) {
            pieces.append(String(format: "G(%.3f,%.3f)", g.0, g.1))
        }
        if let b = (chroma(sd.blue_x), chroma(sd.blue_y)) as? (Double, Double) {
            pieces.append(String(format: "B(%.3f,%.3f)", b.0, b.1))
        }
        if let wx = chroma(sd.white_point_x), let wy = chroma(sd.white_point_y) {
            pieces.append(String(format: "WP(%.3f,%.3f)", wx, wy))
        }
        if let mx = nits(sd.max_luminance) {
            pieces.append(String(format: "L_max %.0f nits", mx))
        }
        if let mn = nits(sd.min_luminance) {
            pieces.append(String(format: "L_min %.4f nits", mn))
        }
        return pieces.joined(separator: " · ")
    }

    // MARK: - AFD

    /// AFD code → localised label per SMPTE 2016-1 table.
    private static func afdLabel(_ code: Int, locale: AppLocale) -> String {
        let key: L10n.Key?
        switch code {
        case 0: key = .afd0
        case 2: key = .afd2
        case 3: key = .afd3
        case 4: key = .afd4
        case 8: key = .afd8
        case 9: key = .afd9
        case 10: key = .afd10
        case 11: key = .afd11
        case 13: key = .afd13
        case 14: key = .afd14
        case 15: key = .afd15
        default: key = nil
        }
        if let k = key { return L10n.t(k, locale) }
        return String(format: L10n.t(.afdCodeFallback, locale), code)
    }

    static func afd(packetDump: String, locale: AppLocale = .fr) -> AFDReport {
        var report = AFDReport()
        guard let data = packetDump.data(using: .utf8) else { return report }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return report }
        guard let packets = json["packets"] as? [[String: Any]] else { return report }

        for packet in packets {
            guard let list = packet["side_data_list"] as? [[String: Any]] else { continue }
            for sd in list {
                if let af = sd["active_format"] as? Int {
                    report.flagPresent = true
                    report.rawValue = af
                    report.description = afdLabel(af, locale: locale)
                    return report
                }
                if let str = sd["active_format"] as? String, let af = Int(str) {
                    report.flagPresent = true
                    report.rawValue = af
                    report.description = afdLabel(af, locale: locale)
                    return report
                }
            }
        }
        return report
    }

    // MARK: - Post-roll trailing black

    static func postRoll(black: [TimeRange], totalDuration: Double?) -> PostRollReport {
        var report = PostRollReport()
        guard let total = totalDuration, total > 0 else { return report }
        if let last = black.last {
            let tail = last.endSec
            if tail >= total - 0.5 {
                report.hasTrailingBlack = true
                report.trailingBlackDurationSec = last.durationSec
            }
        }
        report.endsOnHardCut = !report.hasTrailingBlack
        return report
    }
}
