import Foundation

/// Orchestrates the full QC analysis pipeline and produces a `QCReport`.
struct QCEngine {

    enum Stage: String, CaseIterable {
        case probing, gop, interlace, crop, loudness, phase, audioStats
        case blackDetect, silenceDetect, signalRange, freezeDetect
        case duplicateDetect, deadPixelDetect, pseDetect
        case leaderDetect, audioPops, metadataExtras, finalizing

        func localizedName(_ locale: AppLocale) -> String {
            let key: L10n.Key
            switch self {
            case .probing:          key = .stageProbe
            case .gop:              key = .stageGOP
            case .interlace:        key = .stageInterlace
            case .crop:             key = .stageCrop
            case .loudness:         key = .stageLoudness
            case .phase:            key = .stagePhase
            case .audioStats:       key = .stageAudioStats
            case .blackDetect:      key = .stageBlack
            case .silenceDetect:    key = .stageSilence
            case .signalRange:      key = .stageSignalRange
            case .freezeDetect:     key = .stageFreeze
            case .duplicateDetect:  key = .stageDuplicate
            case .deadPixelDetect:  key = .stageDeadPixel
            case .pseDetect:        key = .stagePSE
            case .leaderDetect:     key = .stageLeader
            case .audioPops:        key = .stageAudioPops
            case .metadataExtras:   key = .stageMetadataExtras
            case .finalizing:       key = .stageFinalize
            }
            return L10n.t(key, locale)
        }
    }

    /// Callback that receives stage updates; always invoked from the engine's task context.
    typealias ProgressCallback = @Sendable (Stage) -> Void

    static func analyze(
        file: URL,
        spec: ChannelSpec,
        versionVariant: VersionVariant? = nil,
        strictness: SignalStrictness = .ebuR103,
        blackMinDurationSec: Double = 1.0,
        silenceMinDurationSec: Double = 1.0,
        locale: AppLocale = .fr,
        progress: ProgressCallback? = nil
    ) async throws -> QCReport {
        progress?(.probing)
        let probe = try await FFprobeRunner.probe(url: file)
        let timecode = try? await FFprobeRunner.firstFrameTimecode(url: file)
        let mxfOP: String? = {
            guard probe.format.format_name?.contains("mxf") == true else { return nil }
            return MXFInspector.operationalPattern(url: file)
        }()

        let resolvedVariant = versionVariant ?? defaultVariant(spec: spec, probe: probe)

        progress?(.gop)
        let gop = try? await GOPInspector.inspect(url: file, maxFrames: 300)

        progress?(.interlace)
        let interlace = try? await FFmpegRunner.detectInterlace(url: file, maxFrames: 600)

        progress?(.crop)
        let crop = try? await FFmpegRunner.detectCrop(url: file, sampleEvery: 25, maxFrames: 600)

        progress?(.loudness)
        let loudness = try await measureLoudnessForMapping(file: file, spec: spec, variant: resolvedVariant, probe: probe)

        progress?(.phase)
        let phaseReports = await measurePhaseForMapping(file: file, spec: spec,
                                                        variant: resolvedVariant, probe: probe)

        progress?(.audioStats)
        let audioStats = try? await FFmpegRunner.measureAudioStats(url: file, streamSelector: "0:a:0")

        progress?(.blackDetect)
        let blackSegments = (try? await FFmpegRunner.detectBlack(
            url: file, minDurationSec: blackMinDurationSec)) ?? []

        progress?(.silenceDetect)
        let silenceSegments = (try? await measureSilenceAcrossTracks(
            file: file, probe: probe, minDurationSec: silenceMinDurationSec)) ?? []

        progress?(.signalRange)
        let bitDepth = probe.videoStreams.first?.bitDepth ?? 8
        let signalPair = try? await FFmpegRunner.measureSignalStats(
            url: file, bitDepth: bitDepth, sampleEvery: 5)
        let signalStats = signalPair?.0
        let timeSeries = signalPair?.1

        progress?(.freezeDetect)
        let frozenSegments = (try? await FFmpegRunner.detectFreeze(
            url: file, noiseThresholdDB: -60.0, minDurationSec: 2.0)) ?? []

        progress?(.duplicateDetect)
        let inputFrameCount = Int(probe.videoStreams.first?.nb_frames ?? "") ?? 0
        let duplicateFrames: DuplicateFramesReport? = inputFrameCount > 0
            ? try? await FFmpegRunner.detectDuplicateFrames(url: file, inputFrameCount: inputFrameCount)
            : nil

        progress?(.deadPixelDetect)
        let deadPixels = try? await DeadPixelDetector.detect(url: file)

        progress?(.pseDetect)
        let pse = try? await FFmpegRunner.detectPSERisk(url: file)

        progress?(.leaderDetect)
        let leader = try? await FFmpegRunner.analyzeLeader(url: file, windowSec: 30.0)

        progress?(.audioPops)
        let audioPops = try? await FFmpegRunner.detectAudioPops(url: file)

        progress?(.metadataExtras)
        let subtitles = MetadataAnalyzer.subtitles(probe: probe)
        let hdr = MetadataAnalyzer.hdr(probe: probe)
        let afd: AFDReport
        if let dump = try? await FFprobeRunner.packetSideDataDump(url: file) {
            afd = MetadataAnalyzer.afd(packetDump: dump, locale: locale)
        } else {
            afd = AFDReport()
        }
        let postRoll = MetadataAnalyzer.postRoll(black: blackSegments,
                                                 totalDuration: probe.format.durationSeconds)

        var content = ContentReport()
        content.blackSegments = blackSegments
        content.silenceSegments = silenceSegments
        content.firstFrameTimecode = timecode
        content.totalDurationSec = probe.format.durationSeconds
        content.signalStats = signalStats
        content.frozenSegments = frozenSegments
        content.duplicateFrames = duplicateFrames
        content.deadPixels = deadPixels
        content.gop = gop
        content.interlace = interlace
        content.crop = crop
        content.phaseReports = phaseReports
        content.audioStats = audioStats
        content.pse = pse
        content.timeSeries = timeSeries
        content.leader = leader
        content.subtitles = subtitles
        content.hdr = hdr
        content.afd = afd
        content.postRoll = postRoll
        content.audioPops = audioPops

        progress?(.finalizing)
        let checks = ChecksBuilder.build(probe: probe, mxfOperationalPattern: mxfOP,
                                          loudness: loudness, content: content,
                                          spec: spec, variant: resolvedVariant,
                                          strictness: strictness, locale: locale)

        return QCReport(
            fileURL: file,
            spec: spec,
            analyzedAt: Date(),
            probe: probe,
            loudness: loudness,
            content: content,
            checks: checks,
            locale: locale
        )
    }

    // MARK: - Mapping helpers

    private static func defaultVariant(spec: ChannelSpec, probe: MediaProbe) -> VersionVariant {
        // Pick the variant whose declared track count matches the actual file structure
        // (sum of audio channels across audio streams).
        let actualChannels = probe.audioStreams.reduce(0) { $0 + ($1.channels ?? 0) }
        let candidates = Set(spec.audio.availableVariants)
        for variant in [VersionVariant.vfVOAD, .vfVO, .vfAD, .vfOnly] where candidates.contains(variant) {
            let tracks = spec.audio.mapping(for: variant) ?? []
            if tracks.count == actualChannels { return variant }
        }
        return .vfOnly
    }

    /// Build amerge filter pairs (left index, right index) — in ffmpeg stream
    /// numbering — for each "stereo couple" found in the mapping.
    private static func loudnessPairs(spec: ChannelSpec, variant: VersionVariant) -> [(label: String, leftIdx: Int, rightIdx: Int)] {
        guard let mapping = spec.audio.mapping(for: variant) else { return [] }
        var pairs: [(String, Int, Int)] = []
        let sorted = mapping.sorted { $0.index < $1.index }
        var i = 0
        while i < sorted.count {
            let t = sorted[i]
            if t.role == .silence { i += 1; continue }
            // Look for a paired right channel immediately after.
            if i + 1 < sorted.count {
                let next = sorted[i + 1]
                if isStereoPair(left: t.role, right: next.role) {
                    let label = pairLabel(role: t.role, leftIdx: t.index, rightIdx: next.index)
                    // mapping indexes are 1-based broadcast tracks → ffmpeg 0-based.
                    pairs.append((label, t.index - 1, next.index - 1))
                    i += 2
                    continue
                }
            }
            i += 1
        }
        return pairs
    }

    private static func isStereoPair(left: AudioTrackRole.Role, right: AudioTrackRole.Role) -> Bool {
        switch (left, right) {
        case (.vfLeft, .vfRight), (.voLeft, .voRight), (.adLeft, .adRight),
             (.dolbyE_L, .dolbyE_R):
            return true
        default:
            return false
        }
    }

    private static func pairLabel(role: AudioTrackRole.Role, leftIdx: Int, rightIdx: Int) -> String {
        let family: String
        switch role {
        case .vfLeft: family = "VF Stéréo"
        case .voLeft: family = "VO Stéréo"
        case .adLeft: family = "Audio Description"
        case .dolbyE_L: family = "Dolby E"
        default: family = "Audio"
        }
        return "\(family) (T\(leftIdx)+T\(rightIdx))"
    }

    private static func measureLoudnessForMapping(
        file: URL,
        spec: ChannelSpec,
        variant: VersionVariant,
        probe: MediaProbe
    ) async throws -> [LoudnessReport] {
        let pairs = loudnessPairs(spec: spec, variant: variant)
        if pairs.isEmpty {
            // Fall back to first audio stream as a single measurement.
            return [try await FFmpegRunner.measureFirstAudioStream(url: file, sourceLabel: "Audio principal")]
        }

        // Decide whether channels live in separate mono streams (typical MXF) or
        // in a single multichannel stream. ffmpeg channel spec encoding differs.
        let audioCount = probe.audioStreams.count
        let useSeparateStreams = audioCount > 1

        var reports: [LoudnessReport] = []
        for pair in pairs {
            let leftSpec: String
            let rightSpec: String
            if useSeparateStreams {
                // 0:a:N — pick the Nth audio stream entirely.
                leftSpec = "0:a:\(pair.leftIdx)"
                rightSpec = "0:a:\(pair.rightIdx)"
            } else {
                // Single multichannel stream — pick channels with stream_index.channel_index syntax.
                leftSpec = "0:a:0:c=\(pair.leftIdx)"
                rightSpec = "0:a:0:c=\(pair.rightIdx)"
            }
            do {
                let r = try await FFmpegRunner.measureLoudness(
                    url: file,
                    sourceLabel: pair.label,
                    leftSpec: leftSpec,
                    rightSpec: rightSpec
                )
                reports.append(r)
            } catch {
                reports.append(LoudnessReport(sourceLabel: pair.label))
            }
        }
        return reports
    }

    private static func measurePhaseForMapping(
        file: URL,
        spec: ChannelSpec,
        variant: VersionVariant,
        probe: MediaProbe
    ) async -> [AudioPhaseReport] {
        let pairs = loudnessPairs(spec: spec, variant: variant)
        let audioCount = probe.audioStreams.count
        let useSeparateStreams = audioCount > 1
        var reports: [AudioPhaseReport] = []
        for pair in pairs {
            let leftSpec: String
            let rightSpec: String
            if useSeparateStreams {
                leftSpec = "0:a:\(pair.leftIdx)"
                rightSpec = "0:a:\(pair.rightIdx)"
            } else {
                leftSpec = "0:a:0:c=\(pair.leftIdx)"
                rightSpec = "0:a:0:c=\(pair.rightIdx)"
            }
            if let r = try? await FFmpegRunner.measureAudioPhase(
                url: file, sourceLabel: pair.label,
                leftSpec: leftSpec, rightSpec: rightSpec) {
                reports.append(r)
            }
        }
        return reports
    }

    private static func measureSilenceAcrossTracks(
        file: URL,
        probe: MediaProbe,
        minDurationSec: Double = 1.0
    ) async throws -> [SilenceSegment] {
        var segments: [SilenceSegment] = []
        // Look only at the first 4 streams to keep analysis fast; the rest are
        // usually silence by spec.
        for i in 0..<min(4, probe.audioStreams.count) {
            let selector = "0:a:\(i)"
            let ranges = (try? await FFmpegRunner.detectSilence(
                url: file,
                streamSelector: selector,
                thresholdDB: -60.0,
                minDurationSec: minDurationSec
            )) ?? []
            for r in ranges {
                segments.append(SilenceSegment(trackIndex: i, range: r))
            }
        }
        return segments
    }
}
