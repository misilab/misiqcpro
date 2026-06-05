import Foundation

/// Compares probe / loudness / content results against a `ChannelSpec` and
/// produces the flat list of `Check` rows that populate the report.
enum ChecksBuilder {

    /// Locale shared by all `tr(_:)` calls during build — set via `build(..., locale:)`.
    private nonisolated(unsafe) static var currentLocale: AppLocale = .fr
    private static func tr(_ key: L10n.Key) -> String { L10n.t(key, currentLocale) }

    static func build(
        probe: MediaProbe,
        mxfOperationalPattern: String? = nil,
        loudness: [LoudnessReport],
        content: ContentReport,
        spec: ChannelSpec,
        variant: VersionVariant,
        strictness: SignalStrictness = .ebuR103,
        locale: AppLocale = .fr
    ) -> [Check] {
        currentLocale = locale
        var checks: [Check] = []
        checks.append(contentsOf: containerChecks(probe: probe, mxfOP: mxfOperationalPattern, spec: spec.video))
        checks.append(contentsOf: videoChecks(probe: probe, spec: spec.video))
        if let stats = content.signalStats {
            checks.append(signalRangeCheck(stats, totalDuration: content.totalDurationSec,
                                            strictness: strictness))
        }
        if !content.frozenSegments.isEmpty {
            checks.append(frozenFramesCheck(content.frozenSegments,
                                            totalDuration: content.totalDurationSec))
        }
        if let dup = content.duplicateFrames {
            checks.append(duplicateFramesCheck(dup,
                                               totalDuration: content.totalDurationSec))
        }
        if let dead = content.deadPixels, dead.sampleImagesCount > 0 {
            checks.append(deadPixelCheck(dead))
        }
        if let gop = content.gop {
            checks.append(gopCheck(gop, spec: spec.video))
        }
        if let interlace = content.interlace, interlace.total > 0 {
            checks.append(interlaceCheck(interlace, spec: spec.video))
        }
        if let crop = content.crop {
            checks.append(cropCheck(crop))
        }
        checks.append(contentsOf: audioChecks(probe: probe, spec: spec.audio, variant: variant))
        for phase in content.phaseReports {
            checks.append(phaseCheck(phase))
        }
        if let stats = content.audioStats {
            checks.append(dcOffsetCheck(stats))
        }
        if let pse = content.pse, pse.totalFramesAnalyzed > 0 {
            checks.append(pseCheck(pse))
        }
        if let loudSpec = spec.loudness {
            checks.append(contentsOf: loudnessChecks(reports: loudness, spec: loudSpec))
        }
        checks.append(contentsOf: structureChecks(content: content, spec: spec.structure))

        if let leader = content.leader {
            checks.append(leaderBarsCheck(leader, spec: spec.structure))
            checks.append(leaderToneCheck(leader, spec: spec.structure))
        }
        if let subs = content.subtitles {
            checks.append(subtitlesCheck(subs, spec: spec.structure))
        }
        if let afd = content.afd {
            checks.append(afdCheck(afd, spec: spec.video))
        }
        if let hdr = content.hdr {
            checks.append(hdrCheck(hdr, spec: spec.video))
        }
        if let postRoll = content.postRoll {
            checks.append(postRollCheck(postRoll, spec: spec.structure))
        }
        if let pops = content.audioPops {
            checks.append(audioPopsCheck(pops))
        }
        return checks
    }

    // MARK: - Leader (bars + 1 kHz tone)

    private static func leaderBarsCheck(_ report: LeaderReport, spec: StructureSpec) -> Check {
        let detected = report.barsDetected
        let actual: String
        if detected {
            actual = String(format: tr(.valBarsLine),
                            String(format: "%.1f", report.barsDurationSec),
                            String(format: "%.0f", report.barsConfidence * 100))
        } else {
            actual = tr(.valNotDetected)
        }
        let expected: String
        let status: CheckStatus
        if spec.requiresLeader == true {
            expected = tr(.yes)
            status = detected ? .pass : .fail
        } else {
            expected = "—"
            status = .pass
        }
        return Check(category: .structure, label: tr(.lblLeaderBars),
                     expected: expected, actual: actual, status: status)
    }

    private static func leaderToneCheck(_ report: LeaderReport, spec: StructureSpec) -> Check {
        let detected = report.toneDetected
        let actual: String
        if detected, let lvl = report.toneLevelDBFS {
            actual = String(format: tr(.valToneLine),
                            String(format: "%.1f", lvl),
                            String(format: "%.0f", report.toneConfidence * 100))
        } else if detected {
            actual = tr(.valDetected)
        } else {
            actual = tr(.valNotDetected)
        }
        let expected: String
        let status: CheckStatus
        if spec.requiresLeader == true {
            expected = tr(.valExpectedTone)
            if detected, let lvl = report.toneLevelDBFS {
                status = abs(lvl + 18) <= 3 ? .pass : .warning
            } else {
                status = .fail
            }
        } else {
            expected = "—"
            status = .pass
        }
        return Check(category: .structure, label: tr(.lblLeaderTone),
                     expected: expected, actual: actual, status: status)
    }

    // MARK: - Subtitles

    private static func subtitlesCheck(_ report: SubtitlesReport, spec: StructureSpec) -> Check {
        let present = report.streamCount > 0 || report.hasClosedCaptions
        let actual: String
        if present {
            var bits: [String] = []
            if report.streamCount > 0 {
                bits.append(String(format: tr(.valSubsStreams), report.streamCount))
                if !report.formats.isEmpty {
                    bits.append(report.formats.joined(separator: ", "))
                }
            }
            if report.hasClosedCaptions { bits.append("CC608/708") }
            if report.hasDVBOrTeletext { bits.append("DVB / Teletext") }
            actual = bits.joined(separator: " · ")
        } else {
            actual = tr(.no)
        }
        let expected: String
        let status: CheckStatus
        if spec.requiresSubtitles == true {
            expected = tr(.yes)
            status = present ? .pass : .fail
        } else {
            expected = "—"
            status = .pass
        }
        return Check(category: .structure, label: tr(.lblSubtitles),
                     expected: expected, actual: actual, status: status)
    }

    // MARK: - AFD

    private static func afdCheck(_ report: AFDReport, spec: VideoSpec) -> Check {
        let actual: String
        if report.flagPresent, let desc = report.description {
            actual = String(format: tr(.valAFDCode), report.rawValue ?? -1, desc)
        } else if report.flagPresent, let raw = report.rawValue {
            actual = "AFD \(raw)"
        } else {
            actual = tr(.valAFDAbsent)
        }
        let expected: String
        let status: CheckStatus
        if spec.requiresAFD == true {
            expected = tr(.yes)
            status = report.flagPresent ? .pass : .fail
        } else {
            expected = "—"
            status = .pass
        }
        return Check(category: .video, label: tr(.lblAFD),
                     expected: expected, actual: actual, status: status)
    }

    // MARK: - HDR

    private static func hdrCheck(_ report: HDRMetadataReport, spec: VideoSpec) -> Check {
        var bits: [String] = []
        if report.hasMasteringDisplay {
            bits.append(tr(.valHDRMaster))
            if let d = report.masteringDisplayDescription { bits.append(d) }
        }
        if report.hasContentLightLevel {
            var cl = tr(.valHDRCLL)
            if let cll = report.maxCLL { cl += " · CLL \(cll)" }
            if let fall = report.maxFALL { cl += " · FALL \(fall)" }
            bits.append(cl)
        }
        if report.hasHDRColorPipeline { bits.append(tr(.valHDRPipeline)) }
        let actual = bits.isEmpty ? tr(.valNoHDR) : bits.joined(separator: " · ")

        let expected: String
        let status: CheckStatus
        if spec.requiresHDRMetadata == true {
            expected = tr(.valExpectedHDR)
            let complete = report.hasMasteringDisplay && report.hasContentLightLevel
            if complete { status = .pass }
            else if report.hasMasteringDisplay || report.hasContentLightLevel { status = .warning }
            else { status = .fail }
        } else {
            expected = "—"
            status = .pass
        }
        return Check(category: .video, label: tr(.lblHDR),
                     expected: expected, actual: actual, status: status)
    }

    // MARK: - Post-roll

    private static func postRollCheck(_ report: PostRollReport, spec: StructureSpec) -> Check {
        let actual: String
        if report.hasTrailingBlack {
            actual = String(format: tr(.valTrailingBlack),
                            String(format: "%.1f", report.trailingBlackDurationSec))
        } else {
            actual = tr(.valHardCut)
        }
        let expected: String
        let status: CheckStatus
        if let minSec = spec.minPostRollSec {
            expected = String(format: "≥ %.1f s", minSec)
            status = report.trailingBlackDurationSec >= minSec ? .pass : .warning
        } else {
            expected = tr(.valExpectedPostRollRecommend)
            status = report.endsOnHardCut ? .warning : .pass
        }
        return Check(category: .structure, label: tr(.lblPostRoll),
                     expected: expected, actual: actual, status: status)
    }

    // MARK: - Audio pops / clicks

    private static func audioPopsCheck(_ report: AudioPopsReport) -> Check {
        let count = report.jumpCount
        let actual: String
        if count == 0 {
            actual = tr(.valNoPops)
        } else if let pts = report.biggestJumpTimeSec {
            actual = String(format: tr(.valPopsLine),
                            count,
                            String(format: "%.1f", report.biggestJumpDB),
                            timecodeShort(pts))
        } else {
            actual = String(format: tr(.valPopsLine),
                            count,
                            String(format: "%.1f", report.biggestJumpDB),
                            "—")
        }
        let expected = "0 > 6 dB"
        let status: CheckStatus
        if count == 0 { status = .pass }
        else if count <= 3 && report.biggestJumpDB < 12 { status = .warning }
        else { status = .fail }
        var detail: String?
        if !report.events.isEmpty {
            let preview = report.events.prefix(5).map {
                String(format: "%@ (%.1f dB)", timecodeShort($0.timeSec), $0.jumpDB)
            }.joined(separator: ", ")
            detail = String(format: tr(.valPopsSample), preview)
        }
        return Check(category: .audio, label: tr(.lblAudioPops),
                     expected: expected, actual: actual, status: status, detail: detail)
    }

    private static func timecodeShort(_ s: Double) -> String {
        let total = Int(s.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let sec = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }

    // MARK: - Container

    private static func containerChecks(probe: MediaProbe, mxfOP: String?, spec: VideoSpec) -> [Check] {
        var rows: [Check] = []
        let actual = probe.format.format_name ?? "—"
        if let accepted = spec.acceptedContainers, !accepted.isEmpty {
            let ok = accepted.contains { actual.localizedCaseInsensitiveContains($0) }
            rows.append(Check(
                category: .container,
                label: tr(.lblContainer),
                expected: accepted.map { $0.uppercased() }.joined(separator: " / "),
                actual: actual.uppercased(),
                status: ok ? .pass : .fail
            ))
        } else if let expected = spec.container {
            let ok = actual.localizedCaseInsensitiveContains(expected)
            rows.append(Check(
                category: .container,
                label: tr(.lblContainer),
                expected: expected.uppercased(),
                actual: actual.uppercased(),
                status: ok ? .pass : .fail
            ))
        }
        if let expectedPattern = spec.operationalPattern, let actualOP = mxfOP {
            // Take the first "OPxx" token of the spec string to compare flexibly
            // (the spec string may be e.g. "OP1a" or "OP1a RDD9").
            let expectedToken = expectedPattern
                .components(separatedBy: .whitespaces)
                .first { $0.uppercased().hasPrefix("OP") } ?? expectedPattern
            let ok = actualOP.caseInsensitiveCompare(expectedToken) == .orderedSame
            rows.append(Check(
                category: .container,
                label: tr(.lblOP),
                expected: expectedPattern,
                actual: actualOP,
                status: ok ? .pass : .fail
            ))
        }
        return rows
    }

    // MARK: - Video

    private static func videoChecks(probe: MediaProbe, spec: VideoSpec) -> [Check] {
        guard let v = probe.videoStreams.first else {
            return [Check(category: .video, label: tr(.lblVideoStream), expected: tr(.valPresent), actual: tr(.valAbsent), status: .fail)]
        }
        var rows: [Check] = []

        let actualCodec = v.codec_name ?? "—"
        if let accepted = spec.acceptedCodecs, !accepted.isEmpty {
            let ok = accepted.contains { actualCodec.localizedCaseInsensitiveContains($0) }
            rows.append(Check(
                category: .video,
                label: tr(.lblVideoCodec),
                expected: accepted.joined(separator: " / "),
                actual: actualCodec,
                status: ok ? .pass : .fail
            ))
        } else if let expected = spec.codec {
            rows.append(Check(
                category: .video,
                label: tr(.lblVideoCodec),
                expected: expected,
                actual: actualCodec,
                status: actualCodec == expected ? .pass : .fail
            ))
        }

        if let expected = spec.profile {
            let actual = v.profile ?? "—"
            // Spec uses "422P@HL", ffprobe shows e.g. "4:2:2".
            let ok = actual.contains("4:2:2") || actual.localizedCaseInsensitiveContains("422")
            rows.append(Check(
                category: .video,
                label: tr(.lblVideoProfile),
                expected: expected,
                actual: actual,
                status: ok ? .pass : .fail
            ))
        }

        let actualRes = v.resolution
        if let accepted = spec.acceptedResolutions, !accepted.isEmpty {
            let ok = actualRes.map { a in accepted.contains { $0.width == a.width && $0.height == a.height } } ?? false
            rows.append(Check(
                category: .video,
                label: tr(.lblResolution),
                expected: accepted.map(\.displayString).joined(separator: " / "),
                actual: actualRes?.displayString ?? "—",
                status: ok ? .pass : .fail
            ))
        } else if let expected = spec.resolution {
            let ok = actualRes.map { $0.width == expected.width && $0.height == expected.height } ?? false
            rows.append(Check(
                category: .video,
                label: tr(.lblResolution),
                expected: expected.displayString,
                actual: actualRes?.displayString ?? "—",
                status: ok ? .pass : .fail
            ))
        }

        let actualFR = v.rationalRate
        if let accepted = spec.acceptedFramerates, !accepted.isEmpty {
            let ok = actualFR.map { a in accepted.contains { $0.equals(a) } } ?? false
            rows.append(Check(
                category: .video,
                label: tr(.lblFramerate),
                expected: accepted.map(\.displayString).joined(separator: " / ") + " fps",
                actual: (actualFR?.displayString ?? "—") + " fps",
                status: ok ? .pass : .fail
            ))
        } else if let expected = spec.framerate {
            let ok = actualFR.map { $0.equals(expected) } ?? false
            rows.append(Check(
                category: .video,
                label: tr(.lblFramerate),
                expected: expected.displayString + " fps",
                actual: (actualFR?.displayString ?? "—") + " fps",
                status: ok ? .pass : .fail
            ))
        }

        // Color space (matrix coefficients)
        let actualSpace = v.color_space
        if let accepted = spec.acceptedColorSpaces, !accepted.isEmpty {
            let ok = actualSpace.map { a in accepted.contains { $0.caseInsensitiveCompare(a) == .orderedSame } } ?? false
            rows.append(Check(
                category: .video,
                label: tr(.lblColorSpace),
                expected: accepted.map(colorSpaceDisplay).joined(separator: " / "),
                actual: actualSpace.map(colorSpaceDisplay) ?? "—",
                status: ok ? .pass : (actualSpace == nil ? .warning : .fail)
            ))
        } else if let expected = spec.colorSpace {
            let ok = actualSpace.map { $0.caseInsensitiveCompare(expected) == .orderedSame } ?? false
            rows.append(Check(
                category: .video,
                label: tr(.lblColorSpace),
                expected: colorSpaceDisplay(expected),
                actual: actualSpace.map(colorSpaceDisplay) ?? "—",
                status: ok ? .pass : (actualSpace == nil ? .warning : .fail)
            ))
        }

        // Color primaries
        let actualPrim = v.color_primaries
        if let accepted = spec.acceptedColorPrimaries, !accepted.isEmpty {
            let ok = actualPrim.map { a in accepted.contains { $0.caseInsensitiveCompare(a) == .orderedSame } } ?? false
            rows.append(Check(
                category: .video,
                label: tr(.lblColorPrimaries),
                expected: accepted.map(colorSpaceDisplay).joined(separator: " / "),
                actual: actualPrim.map(colorSpaceDisplay) ?? "—",
                status: ok ? .pass : (actualPrim == nil ? .warning : .fail)
            ))
        } else if let expected = spec.colorPrimaries {
            let ok = actualPrim.map { $0.caseInsensitiveCompare(expected) == .orderedSame } ?? false
            rows.append(Check(
                category: .video,
                label: tr(.lblColorPrimaries),
                expected: colorSpaceDisplay(expected),
                actual: actualPrim.map(colorSpaceDisplay) ?? "—",
                status: ok ? .pass : (actualPrim == nil ? .warning : .fail)
            ))
        }

        // Color transfer (gamma / EOTF)
        let actualTransfer = v.color_transfer
        if let accepted = spec.acceptedColorTransfers, !accepted.isEmpty {
            let ok = actualTransfer.map { a in accepted.contains { $0.caseInsensitiveCompare(a) == .orderedSame } } ?? false
            rows.append(Check(
                category: .video,
                label: tr(.lblColorTransfer),
                expected: accepted.map(transferDisplay).joined(separator: " / "),
                actual: actualTransfer.map(transferDisplay) ?? "—",
                status: ok ? .pass : (actualTransfer == nil ? .warning : .fail)
            ))
        } else if let expected = spec.colorTransfer {
            let ok = actualTransfer.map { $0.caseInsensitiveCompare(expected) == .orderedSame } ?? false
            rows.append(Check(
                category: .video,
                label: tr(.lblColorTransfer),
                expected: transferDisplay(expected),
                actual: actualTransfer.map(transferDisplay) ?? "—",
                status: ok ? .pass : (actualTransfer == nil ? .warning : .fail)
            ))
        }

        if let expectedAR = spec.aspectRatio {
            let declared = v.display_aspect_ratio ?? "—"
            // Verify SAR is consistent with the spec's DAR if present.
            let computedDARNote: String
            if let sar = v.sample_aspect_ratio, let w = v.width, let h = v.height,
               let (sn, sd) = parseRatio(sar) {
                let darNum = w * sn
                let darDen = h * sd
                let g = gcd(darNum, darDen)
                computedDARNote = String(format: tr(.valComputedDAR), "\(darNum/g):\(darDen/g)")
            } else {
                computedDARNote = ""
            }
            let ok = declared.lowercased().contains(expectedAR.lowercased())
            rows.append(Check(
                category: .video,
                label: tr(.lblAspectRatio),
                expected: expectedAR,
                actual: declared + computedDARNote,
                status: ok ? .pass : (declared == "—" ? .warning : .fail)
            ))
        }

        if let expectedRange = spec.colorRange {
            let actual = v.resolvedColorRange
            let ok = actual.map { $0.caseInsensitiveCompare(expectedRange) == .orderedSame } ?? false
            rows.append(Check(
                category: .video,
                label: tr(.lblColorRange),
                expected: rangeDisplay(expectedRange),
                actual: actual.map(rangeDisplay) ?? "—",
                status: ok ? .pass : (actual == nil ? .warning : .fail),
                detail: actual == nil ? tr(.detColorRangeNotSet) : nil
            ))
        }

        if let expectedInterlaced = spec.interlaced {
            let order = v.field_order ?? "—"
            let actualInterlaced = order != "progressive" && order != "—"
            rows.append(Check(
                category: .video,
                label: tr(.lblInterlace),
                expected: expectedInterlaced ? tr(.interlaced) : tr(.progressive),
                actual: order,
                status: expectedInterlaced == actualInterlaced ? .pass : .fail
            ))
        }

        if let expected = spec.bitrate {
            let actualBps = v.bitRateBps ?? probe.format.bitRateBps
            if let actualBps {
                let verdict = expected.evaluate(actualBps, label: tr(.lblVideoBitrate))
                rows.append(Check(
                    category: .video,
                    label: tr(.lblVideoBitrate),
                    expected: bitrateString(expected.value),
                    actual: bitrateString(actualBps),
                    status: verdict == .pass ? .pass : .fail,
                    detail: verdict == .pass ? nil : verdictReason(verdict)
                ))
            } else {
                rows.append(Check(
                    category: .video,
                    label: tr(.lblVideoBitrate),
                    expected: bitrateString(expected.value),
                    actual: "indisponible",
                    status: .warning
                ))
            }
        }

        // GOP — not parsed in V1.
        // GOP is verified by the dedicated `gopCheck` further down (uses
        // GOPInspector). No placeholder needed here.

        return rows
    }

    // MARK: - Audio

    private static func audioChecks(probe: MediaProbe, spec: AudioSpec, variant: VersionVariant) -> [Check] {
        var rows: [Check] = []

        // Total mono channel count (sum across all audio streams).
        let totalChannels = probe.audioStreams.reduce(0) { $0 + ($1.channels ?? 0) }
        if let accepted = spec.acceptedTrackCounts {
            let ok = accepted.contains(totalChannels)
            rows.append(Check(
                category: .audio,
                label: tr(.lblAudioChannels),
                expected: accepted.map(String.init).joined(separator: " / "),
                actual: "\(totalChannels)",
                status: ok ? .pass : .fail,
                detail: "Variante choisie : \(variant.displayString)"
            ))
        }

        let first = probe.audioStreams.first
        if let expected = spec.codec {
            let actual = first?.codec_name ?? "—"
            rows.append(Check(
                category: .audio,
                label: tr(.lblAudioCodec),
                expected: expected,
                actual: actual,
                status: actual == expected ? .pass : .fail
            ))
        }
        if let expected = spec.bitDepth {
            let actual = first?.bitDepth
            let ok = actual == expected
            rows.append(Check(
                category: .audio,
                label: tr(.lblAudioBitDepth),
                expected: "\(expected) bits",
                actual: actual.map { "\($0) bits" } ?? "—",
                status: ok ? .pass : .fail
            ))
        }
        if let expected = spec.sampleRate {
            let actual = first?.sampleRateHz
            let ok = actual == expected
            rows.append(Check(
                category: .audio,
                label: tr(.lblAudioSampleRate),
                expected: "\(expected) Hz",
                actual: actual.map { "\($0) Hz" } ?? "—",
                status: ok ? .pass : .fail
            ))
        }
        return rows
    }

    // MARK: - Loudness

    private static func loudnessChecks(reports: [LoudnessReport], spec: LoudnessSpec) -> [Check] {
        guard !reports.isEmpty else { return [] }
        var rows: [Check] = []
        for r in reports {
            if let target = spec.integratedTarget, let actual = r.integratedLUFS {
                let verdict = target.evaluate(actual, label: tr(.lblLoudnessIntegrated))
                rows.append(Check(
                    category: .loudness,
                    label: "\(r.sourceLabel) — \(tr(.lblLoudnessIntegrated))",
                    expected: target.displayString + " LUFS",
                    actual: String(format: "%.1f LUFS", actual),
                    status: verdict == .pass ? .pass : .fail,
                    detail: verdict == .pass ? nil : verdictReason(verdict)
                ))
            }
            if let maxTP = spec.maxTruePeak, let actual = r.truePeakDBTP {
                let ok = actual <= maxTP
                rows.append(Check(
                    category: .loudness,
                    label: "\(r.sourceLabel) — \(tr(.lblLoudnessTruePeak))",
                    expected: "≤ \(String(format: "%.1f", maxTP)) dBTP",
                    actual: String(format: "%.1f dBTP", actual),
                    status: ok ? .pass : .fail
                ))
            }
            if let maxLRA = spec.maxLRA, let actual = r.loudnessRangeLU {
                let ok = actual <= maxLRA
                rows.append(Check(
                    category: .loudness,
                    label: "\(r.sourceLabel) — \(tr(.lblLoudnessLRA))",
                    expected: "≤ \(String(format: "%.1f", maxLRA)) LU",
                    actual: String(format: "%.1f LU", actual),
                    status: ok ? .pass : .fail
                ))
            }
        }
        return rows
    }

    // MARK: - Structure

    private static func structureChecks(content: ContentReport, spec: StructureSpec) -> [Check] {
        var rows: [Check] = []

        if let expectedTC = spec.timecodeStart {
            let actual = content.firstFrameTimecode ?? "—"
            let ok = normalizeTimecode(actual) == normalizeTimecode(expectedTC)
            rows.append(Check(
                category: .structure,
                label: tr(.lblTimecodeStart),
                expected: expectedTC,
                actual: actual,
                status: ok ? .pass : (actual == "—" ? .warning : .fail)
            ))
        }

        if let maxBlack = spec.maxBlackDurationSec {
            let worst = content.blackSegments.map(\.durationSec).max() ?? 0
            let ok = worst <= maxBlack
            rows.append(Check(
                category: .structure,
                label: tr(.lblBlackLongest),
                expected: "≤ \(String(format: "%.1f", maxBlack)) s",
                actual: content.blackSegments.isEmpty
                    ? tr(.valNoBlackDetected)
                    : String(format: tr(.fmtBlackActual), String(format: "%.1f", worst), content.blackSegments.count),
                status: ok ? .pass : .fail
            ))
        } else if !content.blackSegments.isEmpty {
            rows.append(Check(
                category: .structure,
                label: tr(.lblBlackDetected),
                expected: tr(.valInformational),
                actual: String(format: tr(.fmtBlackSegmentsCount), content.blackSegments.count),
                status: .warning,
                detail: blackDetailString(content.blackSegments)
            ))
        }

        if let maxSilence = spec.maxSilenceDurationSec {
            let worst = content.silenceSegments.map(\.range.durationSec).max() ?? 0
            let ok = worst <= maxSilence
            rows.append(Check(
                category: .structure,
                label: tr(.lblSilenceLongest),
                expected: "≤ \(String(format: "%.1f", maxSilence)) s",
                actual: content.silenceSegments.isEmpty
                    ? tr(.valNoSilenceAnomaly)
                    : String(format: tr(.fmtSilenceActual), String(format: "%.1f", worst), (content.silenceSegments.first?.trackIndex ?? 0) + 1),
                status: ok ? .pass : .fail
            ))
        }

        if let duration = content.totalDurationSec {
            rows.append(Check(
                category: .structure,
                label: tr(.lblTotalDuration),
                expected: "—",
                actual: formatDuration(duration),
                status: .pass
            ))
        }

        return rows
    }

    // MARK: - Video signal range (3-criterion verdict, like Baton/Cerify)

    /// Three metrics combined to decide the verdict — any one breaching its
    /// fail threshold triggers fail, allowing the check to catch BOTH diffuse
    /// codec noise (high mean) AND localised grading spikes (high peak / wide
    /// Y excursion).
    ///   - meanBRNG     : average % of pixels OOR per frame
    ///   - peakBRNG     : worst single-frame OOR ratio
    ///   - YExcursion% : how far the global Y extremes exceed the legal range,
    ///                   in % of the legal range span
    private static func signalRangeCheck(_ stats: SignalStatsReport,
                                         totalDuration: Double?,
                                         strictness: SignalStrictness) -> Check {
        let t = strictness.thresholds
        let sigPassMeanPct  = t.passMean
        let sigPassPeakPct  = t.passPeak
        let sigPassYPct     = t.passY
        let sigWarnMeanPct  = t.warnMean
        let sigWarnPeakPct  = t.warnPeak
        let sigWarnYPct     = t.warnY
        let range = SignalStatsReport.legalRange(forBitDepth: stats.bitDepth)
        let rawMinMax: String
        if let lo = stats.minYMin, let hi = stats.maxYMax {
            rawMinMax = "Y \(lo)–\(hi) (\(stats.bitDepth) bits)"
        } else {
            rawMinMax = "Y — / —"
        }

        // % of pixels OOR per frame
        let meanPct = stats.meanPixelBRNG * 100
        let peakPct = stats.peakPixelBRNG * 100

        // How far Y extremes escape, as % of the legal range span
        let rangeSpan = Double(range.high - range.low)
        let belowAmt = stats.minYMin.map { max(0.0, Double(range.low - $0)) } ?? 0
        let aboveAmt = stats.maxYMax.map { max(0.0, Double($0 - range.high)) } ?? 0
        let yExcursionPct = rangeSpan > 0 ? max(belowAmt, aboveAmt) / rangeSpan * 100 : 0

        let actual = String(format: tr(.fmtSignalActual),
                            String(format: "%.2f", meanPct),
                            String(format: "%.2f", peakPct),
                            rawMinMax,
                            String(format: "%.1f", yExcursionPct))
        let expected = String(format: tr(.fmtSignalRangeExpected), range.low, range.high)

        let status: CheckStatus
        var failedCriteria: [String] = []

        if stats.framesSampled == 0 || (stats.minYMin == nil && stats.maxYMax == nil) {
            return Check(
                category: .video, label: tr(.lblSignalRange),
                expected: expected, actual: actual, status: .warning,
                detail: tr(.errSignalUnavailable))
        }

        // Determine the worst-grade verdict across the three criteria.
        let meanOK_pass = meanPct <= sigPassMeanPct
        let peakOK_pass = peakPct <= sigPassPeakPct
        let yOK_pass    = yExcursionPct <= sigPassYPct
        let meanOK_warn = meanPct <= sigWarnMeanPct
        let peakOK_warn = peakPct <= sigWarnPeakPct
        let yOK_warn    = yExcursionPct <= sigWarnYPct

        if meanOK_pass && peakOK_pass && yOK_pass {
            status = .pass
        } else if meanOK_warn && peakOK_warn && yOK_warn {
            status = .warning
            if !meanOK_pass {
                failedCriteria.append(String(format: tr(.fmtSignalMeanWarn),
                                              String(format: "%.2f", meanPct),
                                              String(format: "%.2f", sigPassMeanPct)))
            }
            if !peakOK_pass {
                failedCriteria.append(String(format: tr(.fmtSignalPeakWarn),
                                              String(format: "%.2f", peakPct),
                                              String(format: "%.1f", sigPassPeakPct)))
            }
            if !yOK_pass {
                failedCriteria.append(String(format: tr(.fmtSignalYWarn),
                                              String(format: "%.1f", yExcursionPct)))
            }
        } else {
            status = .fail
            if !meanOK_warn {
                failedCriteria.append(String(format: tr(.fmtSignalMeanFail),
                                              String(format: "%.2f", meanPct),
                                              String(format: "%.1f", sigWarnMeanPct)))
            }
            if !peakOK_warn {
                failedCriteria.append(String(format: tr(.fmtSignalPeakFail),
                                              String(format: "%.2f", peakPct),
                                              String(format: "%.1f", sigWarnPeakPct)))
            }
            if !yOK_warn {
                failedCriteria.append(String(format: tr(.fmtSignalYFail),
                                              String(format: "%.1f", yExcursionPct)))
            }
        }

        var kinds: [String] = []
        if stats.framesWithInfraBlack > 0 { kinds.append(tr(.valInfraBlack)) }
        if stats.framesWithSuperWhite > 0 { kinds.append(tr(.valSuperWhite)) }

        var detailParts: [String] = []
        if !failedCriteria.isEmpty { detailParts.append(failedCriteria.joined(separator: " · ")) }
        if !kinds.isEmpty && status != .pass {
            detailParts.append(String(format: tr(.fmtSignalKindLabel),
                                      kinds.joined(separator: " + ")))
        }
        if status == .pass {
            detailParts.append(String(format: tr(.fmtSignalPass), stats.framesSampled))
        } else if status == .warning {
            detailParts.append(tr(.detSignalWarn))
        } else {
            detailParts.append(tr(.detSignalFail))
        }

        return Check(
            category: .video,
            label: tr(.lblSignalRange),
            expected: expected,
            actual: actual,
            status: status,
            detail: detailParts.joined(separator: " — ")
        )
    }

    // MARK: - Frozen frames

    private static func frozenFramesCheck(_ segments: [TimeRange],
                                          totalDuration: Double?) -> Check {
        let totalFrozenSec = segments.reduce(0) { $0 + $1.durationSec }
        let worst = segments.map(\.durationSec).max() ?? 0
        let pct = totalDuration.map { $0 > 0 ? (totalFrozenSec / $0) * 100 : 0 } ?? 0

        let firstStarts = segments.prefix(3).map {
            "@" + formatTimecode($0.startSec)
        }.joined(separator: ", ")

        let actual = String(format: tr(.fmtFreezeActual),
                            segments.count,
                            String(format: "%.1f", totalFrozenSec),
                            String(format: "%.1f", pct))
        let detail = String(format: tr(.fmtFreezeDetail),
                            String(format: "%.1f", worst),
                            firstStarts)

        return Check(
            category: .structure,
            label: tr(.lblFreeze),
            expected: tr(.expFreezeNone),
            actual: actual,
            status: .fail,
            detail: detail
        )
    }

    private static func formatTimecode(_ s: Double) -> String {
        let h = Int(s) / 3600
        let m = (Int(s) % 3600) / 60
        let sec = Int(s) % 60
        return String(format: "%02d:%02d:%02d", h, m, sec)
    }

    // MARK: - Duplicate / dropped frames

    /// Mild duplicates (≤ 0.5%) can be normal cadence / encoder artefacts.
    /// Above 1% the file very likely has a botched 29.97 → 25 conversion or
    /// 3:2 pulldown residue.
    private static let dupWarnRatio: Double = 0.005
    private static let dupFailRatio: Double = 0.01

    private static func duplicateFramesCheck(_ report: DuplicateFramesReport,
                                             totalDuration: Double?) -> Check {
        let pct = report.duplicateRatio * 100
        let durStr = totalDuration.map {
            String(format: "%.1f s", $0 * report.duplicateRatio)
        } ?? "—"
        let actual = String(
            format: tr(.fmtDupActual),
            report.duplicateFrameCount, report.inputFrameCount,
            String(format: "%.2f", pct), durStr
        )
        let expected = tr(.expDupCadence)

        let status: CheckStatus
        var detail: String?
        if report.inputFrameCount == 0 {
            status = .warning
            detail = tr(.detDupUnknown)
        } else if report.duplicateRatio <= dupWarnRatio {
            status = .pass
            detail = tr(.detDupPass)
        } else if report.duplicateRatio <= dupFailRatio {
            status = .warning
            detail = tr(.detDupWarn)
        } else {
            status = .fail
            detail = tr(.detDupFail)
        }
        return Check(
            category: .structure,
            label: tr(.lblDuplicateFrames),
            expected: expected,
            actual: actual,
            status: status,
            detail: detail
        )
    }

    // MARK: - GOP structure (real parsing)

    private static func gopCheck(_ report: GOPReport, spec: VideoSpec) -> Check {
        // If the spec doesn't pin GOP, this is informational only.
        let expectedSize = spec.gopSize
        let expectedClosed = spec.gopClosed
        let avgStr = String(format: "%.1f", report.averageGopLength)
        let actual = "moy. \(avgStr) frames · max \(report.maxGopLength) · " +
            "\(report.iFrameCount) I-frames sur \(report.totalFramesAnalyzed) analysées · " +
            (report.closedGop.map { $0 ? "closed" : "open" } ?? "—")
        let expected: String = {
            switch (expectedSize, expectedClosed) {
            case let (s?, c?): return "\(s) frames \(c ? "closed" : "open")"
            case let (s?, nil): return "\(s) frames"
            case (nil, _): return "informationnel"
            }
        }()
        guard report.totalFramesAnalyzed > 0 else {
            return Check(category: .video, label: tr(.lblGopStructure),
                         expected: expected, actual: "—", status: .warning,
                         detail: "Aucune frame analysée.")
        }
        var status: CheckStatus = .pass
        var problems: [String] = []
        if let s = expectedSize, report.maxGopLength > s {
            status = .fail
            problems.append("max GOP \(report.maxGopLength) > attendu \(s)")
        }
        if let c = expectedClosed, let actualClosed = report.closedGop, c != actualClosed {
            status = .fail
            problems.append(actualClosed ? "détecté closed, attendu open" : "détecté open, attendu closed")
        }
        return Check(category: .video, label: tr(.lblGopStructure),
                     expected: expected, actual: actual, status: status,
                     detail: problems.isEmpty ? nil : problems.joined(separator: " · "))
    }

    // MARK: - Interlace / scan mode (idet)

    private static func interlaceCheck(_ report: InterlaceReport, spec: VideoSpec) -> Check {
        let detected = report.dominant
        let detectedLabel: String
        switch detected {
        case "tt": detectedLabel = tr(.scanTFF)
        case "bb": detectedLabel = tr(.scanBFF)
        case "progressive": detectedLabel = tr(.scanProgressive)
        default:   detectedLabel = tr(.scanUndetermined)
        }
        let expected: String
        let status: CheckStatus
        var detail: String?
        if let expectedInter = spec.interlaced {
            expected = expectedInter ? tr(.interlaced) : tr(.progressive)
            if expectedInter {
                // Spec demands interlaced (1080i25 / 50 Hz broadcast EU).
                switch detected {
                case "tt", "bb":
                    status = .pass          // True interlace capture.
                case "progressive":
                    status = .warning       // Almost certainly PsF — flag for human review.
                    detail = tr(.scanPsFDetail)
                default:
                    status = .warning
                    detail = tr(.scanUndeterminedDetail)
                }
            } else {
                // Spec demands progressive (OTT / streaming platforms).
                switch detected {
                case "progressive":
                    status = .pass
                case "tt", "bb":
                    status = .fail
                    detail = tr(.scanInterlacedOnProgressiveDetail)
                default:
                    status = .warning
                    detail = tr(.scanUndeterminedDetail)
                }
            }
        } else {
            expected = "—"
            status = .pass
        }
        let actual = "\(detectedLabel) · " +
            "\(tr(.scanCountTFF)) \(report.tff) · " +
            "\(tr(.scanCountBFF)) \(report.bff) · " +
            "\(tr(.scanCountProgressive)) \(report.progressive) · " +
            "\(tr(.scanCountUndetermined)) \(report.undetermined)"
        return Check(category: .video, label: tr(.lblScanMode),
                     expected: expected, actual: actual,
                     status: status, detail: detail)
    }

    // MARK: - Letterbox / pillarbox

    private static func cropCheck(_ report: CropReport) -> Check {
        let actual = String(format: tr(.fmtFramingActual),
                            report.recommended.w, report.recommended.h,
                            report.recommended.x, report.recommended.y,
                            report.inputWidth, report.inputHeight)
        let status: CheckStatus = report.isFullFrame ? .pass : .warning
        var detail: String?
        if report.hasLetterbox && report.hasPillarbox {
            detail = tr(.detFramingBoth)
        } else if report.hasLetterbox {
            detail = tr(.detLetterbox)
        } else if report.hasPillarbox {
            detail = tr(.detPillarbox)
        }
        return Check(category: .video, label: tr(.lblFraming),
                     expected: tr(.expFramingFull), actual: actual,
                     status: status, detail: detail)
    }

    // MARK: - Stereo phase correlation

    private static func phaseCheck(_ report: AudioPhaseReport) -> Check {
        let pctAnti = report.antiPhaseRatio * 100
        let actual = String(format: tr(.fmtPhaseActual),
                            String(format: "%.2f", report.meanPhase),
                            String(format: "%.2f", report.minPhase),
                            String(format: "%.1f", pctAnti))
        let expected = tr(.expPhaseMono)
        let status: CheckStatus
        var detail: String?
        if report.meanPhase >= 0.5 {
            status = .pass
            detail = tr(.detPhasePass)
        } else if report.meanPhase >= 0 {
            status = .warning
            detail = tr(.detPhaseWarn)
        } else {
            status = .fail
            detail = tr(.detPhaseFail)
        }
        return Check(category: .loudness,
                     label: String(format: tr(.lblPhasePrefix), report.sourceLabel),
                     expected: expected, actual: actual,
                     status: status, detail: detail)
    }

    // MARK: - Audio DC offset

    private static func dcOffsetCheck(_ stats: AudioStatsReport) -> Check {
        let pct = stats.dcOffsetPct
        let actual = String(format: tr(.fmtDCActual),
                            String(format: "%.4f", stats.overallDCOffset),
                            String(format: "%.3f", pct))
        let expected = tr(.expDCOffset)
        let status: CheckStatus
        var detail: String?
        if pct <= 0.1 {
            status = .pass
        } else if pct <= 1.0 {
            status = .warning
            detail = tr(.detDCWarn)
        } else {
            status = .fail
            detail = tr(.detDCFail)
        }
        return Check(category: .loudness,
                     label: tr(.lblDCOffset),
                     expected: expected, actual: actual,
                     status: status, detail: detail)
    }

    // MARK: - PSE / Photosensitive epilepsy

    private static func pseCheck(_ report: PSEReport) -> Check {
        let actual = String(format: tr(.fmtPSEActual),
                            report.flashEventCount,
                            String(format: "%.1f", report.peakFlashesPerSec),
                            report.riskySegments.count)
        let expected = tr(.expPSE)
        let status: CheckStatus
        var detail: String?
        if report.riskySegments.isEmpty {
            status = .pass
            detail = tr(.detPSEPass)
        } else if report.peakFlashesPerSec <= 5 {
            status = .warning
            let firstTimes = report.riskySegments.prefix(3).map { "@" + formatTimecode($0.startSec) }.joined(separator: ", ")
            detail = String(format: tr(.detPSEWarn), firstTimes)
        } else {
            status = .fail
            let firstTimes = report.riskySegments.prefix(5).map { "@" + formatTimecode($0.startSec) }.joined(separator: ", ")
            detail = String(format: tr(.detPSEFail),
                            String(format: "%.1f", report.peakFlashesPerSec),
                            report.riskySegments.count,
                            firstTimes)
        }
        return Check(
            category: .video,
            label: tr(.lblPSE),
            expected: expected,
            actual: actual,
            status: status,
            detail: detail
        )
    }

    // MARK: - Dead / stuck pixels

    /// Even a handful of stuck pixels is suspect for broadcast delivery, but
    /// a few false positives are normal on flat areas. We use:
    ///   - PASS : < 0.05% of sampled positions
    ///   - WARN : 0.05–0.5%
    ///   - FAIL : > 0.5%
    private static func deadPixelCheck(_ report: DeadPixelReport) -> Check {
        let pct = report.stuckRatio * 100
        let actual = String(
            format: tr(.fmtDeadPixelActual),
            report.stuckCount, report.sampledPixels,
            String(format: "%.3f", pct), report.sampleImagesCount
        )
        let expected = tr(.expDeadPixel)
        let status: CheckStatus
        var detail: String?
        if report.stuckRatio <= 0.0005 {
            status = .pass
            detail = tr(.detDeadPixelPass)
        } else if report.stuckRatio <= 0.005 {
            status = .warning
            detail = tr(.detDeadPixelWarn)
        } else {
            status = .fail
            detail = tr(.detDeadPixelFail)
        }
        return Check(
            category: .structure,
            label: tr(.lblStuckPixels),
            expected: expected,
            actual: actual,
            status: status,
            detail: detail
        )
    }

    // MARK: - Helpers

    private static func verdictReason(_ v: Tolerance.Verdict) -> String? {
        if case .fail(let r) = v { return r }
        return nil
    }

    private static func bitrateString(_ bps: Double?) -> String {
        guard let bps else { return "—" }
        let mb = bps / 1_000_000
        return String(format: "%.1f Mb/s", mb)
    }

    private static func formatDuration(_ s: Double) -> String {
        let h = Int(s) / 3600
        let m = (Int(s) % 3600) / 60
        let sec = Int(s) % 60
        return String(format: "%02d:%02d:%02d", h, m, sec)
    }

    nonisolated private static func colorSpaceDisplay(_ raw: String) -> String {
        switch raw.lowercased() {
        case "bt709":      return "Rec. 709"
        case "bt2020nc":   return "Rec. 2020 NCL"
        case "bt2020c":    return "Rec. 2020 CL"
        case "bt2020":     return "Rec. 2020"
        case "smpte170m":  return "SMPTE 170M (NTSC)"
        case "bt470bg":    return "BT.470BG (PAL)"
        case "rgb":        return "RGB"
        default: return raw
        }
    }

    nonisolated private static func transferDisplay(_ raw: String) -> String {
        switch raw.lowercased() {
        case "bt709":         return "Rec. 709 (Gamma 2.4)"
        case "smpte170m":     return "SMPTE 170M"
        case "bt2020-10":     return "Rec. 2020 10-bit"
        case "bt2020-12":     return "Rec. 2020 12-bit"
        case "smpte2084":     return "SMPTE ST 2084 (PQ HDR)"
        case "arib-std-b67":  return "ARIB STD-B67 (HLG)"
        case "linear":        return "Linéaire"
        case "iec61966-2-1":  return "sRGB"
        default: return raw
        }
    }

    private static func parseRatio(_ s: String) -> (Int, Int)? {
        let parts = s.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2, parts[0] > 0, parts[1] > 0 else { return nil }
        return (parts[0], parts[1])
    }

    private static func gcd(_ a: Int, _ b: Int) -> Int {
        var x = abs(a), y = abs(b)
        while y != 0 { (x, y) = (y, x % y) }
        return x == 0 ? 1 : x
    }

    nonisolated private static func rangeDisplay(_ raw: String) -> String {
        switch raw.lowercased() {
        case "tv", "legal", "narrow", "limited": return "Video Range (legal)"
        case "pc", "full":                       return "Full Range"
        default: return raw
        }
    }

    private static func normalizeTimecode(_ tc: String) -> String {
        // Accept "HH:MM:SS:FF" and "HH:MM:SS;FF" (drop-frame).
        tc.replacingOccurrences(of: ";", with: ":")
    }

    private static func blackDetailString(_ ranges: [TimeRange]) -> String {
        ranges.prefix(5).map { String(format: "%.1f–%.1fs", $0.startSec, $0.endSec) }.joined(separator: ", ")
    }
}
