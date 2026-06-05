import Foundation

/// Runs `ffmpeg` with analysis filters (ebur128, blackdetect, silencedetect) and
/// parses the textual results out of stderr.
enum FFmpegRunner {

    // MARK: - Loudness (EBU R128)

    /// Measures integrated loudness, true peak and LRA on a stereo pair built
    /// from two source channels.
    ///
    /// - Parameters:
    ///   - url: media file
    ///   - leftSpec / rightSpec: ffmpeg channel spec (e.g. `0.0`, `1.0`) referring
    ///     to *stream index . channel index*. For an 8-stream mono MXF you'd pass
    ///     `0.0` and `1.0`. For a single 8-ch stream you'd pass `0.0` and `0.1`.
    static func measureLoudness(
        url: URL,
        sourceLabel: String,
        leftSpec: String,
        rightSpec: String
    ) async throws -> LoudnessReport {
        let binary = try BinaryLocator.ffmpegURL()
        let result = try await ProcessRunner.run(
            executable: binary,
            arguments: [
                "-nostdin", "-hide_banner", "-nostats",
                "-i", url.path,
                "-filter_complex",
                "[\(leftSpec)][\(rightSpec)]amerge=inputs=2,ebur128=peak=true",
                "-vn",
                "-f", "null", "-"
            ],
            throwOnNonZeroExit: false
        )
        return parseEBUR128(stderr: result.stderr, sourceLabel: sourceLabel)
    }

    /// Measures loudness on the file's first audio stream as-is (no remapping).
    static func measureFirstAudioStream(url: URL, sourceLabel: String) async throws -> LoudnessReport {
        let binary = try BinaryLocator.ffmpegURL()
        let result = try await ProcessRunner.run(
            executable: binary,
            arguments: [
                "-nostdin", "-hide_banner", "-nostats",
                "-i", url.path,
                "-map", "0:a:0",
                "-af", "ebur128=peak=true",
                "-vn",
                "-f", "null", "-"
            ],
            throwOnNonZeroExit: false
        )
        return parseEBUR128(stderr: result.stderr, sourceLabel: sourceLabel)
    }

    // MARK: - Black detect

    static func detectBlack(url: URL, minDurationSec: Double = 1.0) async throws -> [TimeRange] {
        let binary = try BinaryLocator.ffmpegURL()
        let filter = "blackdetect=d=\(minDurationSec):pix_th=0.05"
        let result = try await ProcessRunner.run(
            executable: binary,
            arguments: [
                "-nostdin", "-hide_banner", "-nostats",
                "-i", url.path,
                "-an",
                "-vf", filter,
                "-f", "null", "-"
            ],
            throwOnNonZeroExit: false
        )
        return parseBlackDetect(stderr: result.stderr)
    }

    // MARK: - Silence detect

    static func detectSilence(
        url: URL,
        streamSelector: String = "0:a:0",
        thresholdDB: Double = -60.0,
        minDurationSec: Double = 1.0
    ) async throws -> [TimeRange] {
        let binary = try BinaryLocator.ffmpegURL()
        let filter = "silencedetect=n=\(thresholdDB)dB:d=\(minDurationSec)"
        let result = try await ProcessRunner.run(
            executable: binary,
            arguments: [
                "-nostdin", "-hide_banner", "-nostats",
                "-i", url.path,
                "-map", streamSelector,
                "-af", filter,
                "-vn",
                "-f", "null", "-"
            ],
            throwOnNonZeroExit: false
        )
        return parseSilenceDetect(stderr: result.stderr)
    }

    // MARK: - Signal stats (luma min/max — infra-black / super-white)

    /// Runs the `signalstats` filter sampling every `sampleEvery` frames and
    /// returns the worst luma minimum / maximum across the sample set.
    /// `bitDepth` lets the report express results in the codec's range.
    static func measureSignalStats(
        url: URL,
        bitDepth: Int,
        sampleEvery: Int = 5
    ) async throws -> (SignalStatsReport, TimeSeriesReport) {
        let binary = try BinaryLocator.ffmpegURL()
        // brng = pixel OOR ratio · tout = temporal outliers · vrep = vertical
        // line repetitions (head clog, dropouts).
        let filter = sampleEvery > 1
            ? "select='not(mod(n\\,\(sampleEvery)))',signalstats=stat=brng+tout+vrep,metadata=mode=print:file=-"
            : "signalstats=stat=brng+tout+vrep,metadata=mode=print:file=-"
        let result = try await ProcessRunner.run(
            executable: binary,
            arguments: [
                "-nostdin", "-hide_banner", "-nostats",
                "-i", url.path,
                "-an", "-vf", filter,
                "-f", "null", "-"
            ],
            throwOnNonZeroExit: false
        )
        let report = parseSignalStats(stdout: result.stdout, fallbackBitDepth: bitDepth)
        var series = parseTimeSeries(stdout: result.stdout, fallbackBitDepth: bitDepth)
        series.samplingStride = sampleEvery
        return (report, series)
    }

    /// Walks the same metadata stream as `parseSignalStats` but keeps every
    /// frame as a `TimeSeriesPoint`. Used by the timeline chart and CSV export.
    static func parseTimeSeries(stdout: String, fallbackBitDepth: Int) -> TimeSeriesReport {
        var report = TimeSeriesReport(bitDepth: fallbackBitDepth)
        var pendingPts: Double?
        var pendingYMin: Int?
        var pendingYMax: Int?
        var pendingYAvg: Double?
        var pendingBRNG: Double?
        var pendingTout: Double?
        var pendingVrep: Double?
        var pendingBitDepth: Int?
        var frameOpen = false
        var lastPts: Double = 0

        func flush() {
            guard frameOpen else { return }
            if let bd = pendingBitDepth, report.points.isEmpty {
                report.bitDepth = bd
            }
            let pts = pendingPts ?? lastPts
            let point = TimeSeriesPoint(
                pts: pts,
                yAvg: pendingYAvg ?? 0,
                yMin: pendingYMin ?? 0,
                yMax: pendingYMax ?? 0,
                brng: pendingBRNG ?? 0,
                tout: pendingTout ?? 0,
                vrep: pendingVrep ?? 0
            )
            report.points.append(point)
            lastPts = pts
            pendingPts = nil
            pendingYMin = nil; pendingYMax = nil; pendingYAvg = nil
            pendingBRNG = nil; pendingTout = nil; pendingVrep = nil
            pendingBitDepth = nil
            frameOpen = false
        }

        for raw in stdout.split(whereSeparator: { $0.isNewline }) {
            let line = String(raw)
            if line.hasPrefix("frame:") {
                flush()
                frameOpen = true
                if let r = line.range(of: "pts_time:") {
                    let rest = line[r.upperBound...]
                    let token = rest.prefix(while: { ch in
                        ch == "-" || ch == "." || ch.isNumber
                    })
                    pendingPts = Double(token)
                }
            } else if let v = extractInt(in: line, after: "lavfi.signalstats.YMIN=") {
                pendingYMin = v
            } else if let v = extractInt(in: line, after: "lavfi.signalstats.YMAX=") {
                pendingYMax = v
            } else if let v = extractDouble(in: line, after: "lavfi.signalstats.YAVG=") {
                pendingYAvg = v
            } else if let v = extractDouble(in: line, after: "lavfi.signalstats.BRNG=") {
                pendingBRNG = v
            } else if let v = extractDouble(in: line, after: "lavfi.signalstats.TOUT=") {
                pendingTout = v
            } else if let v = extractDouble(in: line, after: "lavfi.signalstats.VREP=") {
                pendingVrep = v
            } else if let v = extractInt(in: line, after: "lavfi.signalstats.YBITDEPTH=") {
                pendingBitDepth = v
            }
        }
        flush()
        report.durationSec = report.points.last?.pts ?? 0
        return report
    }

    /// Parses ffmpeg's `metadata=mode=print` output of the signalstats filter
    /// frame-by-frame. We now extract:
    ///   - YMIN / YMAX  → global Y extremes
    ///   - BRNG         → pixel-level out-of-range ratio per frame (the metric
    ///     pro QC tools use)
    ///   - YBITDEPTH    → auto-detect bit depth
    static func parseSignalStats(stdout: String, fallbackBitDepth: Int) -> SignalStatsReport {
        var report = SignalStatsReport(bitDepth: fallbackBitDepth)
        var legal = SignalStatsReport.legalRange(forBitDepth: fallbackBitDepth)

        var pendingYMin: Int?
        var pendingYMax: Int?
        var pendingBRNG: Double?
        var pendingBitDepth: Int?
        var brngSum: Double = 0
        var brngCount: Int = 0
        var frameOpen = false

        func flush() {
            guard frameOpen else { return }
            // First frame: lock in the detected bit depth + recompute legal range.
            if let bd = pendingBitDepth, report.framesSampled == 0 {
                report.bitDepth = bd
                legal = SignalStatsReport.legalRange(forBitDepth: bd)
            }
            report.framesSampled += 1
            if let v = pendingYMin {
                report.minYMin = min(report.minYMin ?? Int.max, v)
                if v < legal.low { report.framesWithInfraBlack += 1 }
            }
            if let v = pendingYMax {
                report.maxYMax = max(report.maxYMax ?? Int.min, v)
                if v > legal.high { report.framesWithSuperWhite += 1 }
            }
            if let b = pendingBRNG {
                brngSum += b
                brngCount += 1
                report.peakPixelBRNG = max(report.peakPixelBRNG, b)
            }
            pendingYMin = nil
            pendingYMax = nil
            pendingBRNG = nil
            pendingBitDepth = nil
            frameOpen = false
        }

        for raw in stdout.split(whereSeparator: { $0.isNewline }) {
            let line = String(raw)
            if line.hasPrefix("frame:") {
                flush()
                frameOpen = true
            } else if let v = extractInt(in: line, after: "lavfi.signalstats.YMIN=") {
                pendingYMin = v
            } else if let v = extractInt(in: line, after: "lavfi.signalstats.YMAX=") {
                pendingYMax = v
            } else if let v = extractDouble(in: line, after: "lavfi.signalstats.BRNG=") {
                pendingBRNG = v
            } else if let v = extractInt(in: line, after: "lavfi.signalstats.YBITDEPTH=") {
                pendingBitDepth = v
            }
        }
        flush()

        if brngCount > 0 {
            report.meanPixelBRNG = brngSum / Double(brngCount)
        }
        return report
    }

    // MARK: - PSE / Photosensitivity (Harding-inspired)

    /// Runs `signalstats` on a downscaled stream at full frame rate and uses
    /// the YAVG (mean luma) time series to detect rapid luminance changes
    /// indicative of strobing / flashing content. Threshold defaults to 20% of
    /// the codec range and 1-second sliding window with > 3 transitions = risky.
    static func detectPSERisk(url: URL) async throws -> PSEReport {
        let binary = try BinaryLocator.ffmpegURL()
        let filter = "scale=320:180,signalstats,metadata=mode=print:file=-"
        let result = try await ProcessRunner.run(
            executable: binary,
            arguments: [
                "-nostdin", "-hide_banner", "-nostats",
                "-i", url.path,
                "-an", "-vf", filter,
                "-f", "null", "-"
            ],
            throwOnNonZeroExit: false
        )
        return parsePSE(stdout: result.stdout)
    }

    static func parsePSE(stdout: String) -> PSEReport {
        // Pair (pts_time, YAVG) per frame.
        var samples: [(pts: Double, yavg: Double)] = []
        var currentPts: Double?
        var frameCounter = 0

        for raw in stdout.split(whereSeparator: { $0.isNewline }) {
            let line = String(raw)
            if line.hasPrefix("frame:") {
                if let r = line.range(of: "pts_time:") {
                    let rest = line[r.upperBound...]
                    let token = rest.prefix(while: { ch in
                        ch == "-" || ch == "." || ch.isNumber
                    })
                    currentPts = Double(token)
                } else {
                    currentPts = nil
                }
            } else if let yavg = extractDouble(in: line, after: "lavfi.signalstats.YAVG=") {
                let pts = currentPts ?? (Double(frameCounter) / 25.0)
                samples.append((pts, yavg))
                frameCounter += 1
            }
        }

        guard samples.count >= 2 else { return PSEReport() }

        // signalstats outputs YAVG in the codec's native range — after scale to
        // 320:180 ffmpeg falls back to 8-bit YUV, so the practical max is 255.
        let maxLuma = 255.0
        let threshold = maxLuma * 0.20

        var flashTimes: [Double] = []
        for i in 1..<samples.count {
            if abs(samples[i].yavg - samples[i - 1].yavg) > threshold {
                flashTimes.append(samples[i].pts)
            }
        }

        // Sliding 1-second window: count flashes within [t, t+1] for every flash t.
        var peakRate = 0.0
        var riskyRanges: [TimeRange] = []
        var inRisky = false
        var riskyStart = 0.0
        var lastTime = 0.0

        for i in 0..<flashTimes.count {
            var j = i
            while j < flashTimes.count && flashTimes[j] - flashTimes[i] <= 1.0 {
                j += 1
            }
            let rateInWindow = Double(j - i)
            if rateInWindow > peakRate { peakRate = rateInWindow }
            lastTime = flashTimes[i]
            if rateInWindow > 3 && !inRisky {
                inRisky = true
                riskyStart = flashTimes[i]
            } else if rateInWindow <= 3 && inRisky {
                inRisky = false
                riskyRanges.append(TimeRange(startSec: riskyStart, endSec: flashTimes[i]))
            }
        }
        if inRisky {
            riskyRanges.append(TimeRange(startSec: riskyStart, endSec: lastTime))
        }

        var report = PSEReport()
        report.flashEventCount = flashTimes.count
        report.peakFlashesPerSec = peakRate
        report.riskySegments = riskyRanges
        report.totalFramesAnalyzed = samples.count
        report.thresholdFraction = 0.20
        return report
    }

    // MARK: - Interlace detection (idet)

    static func detectInterlace(url: URL, maxFrames: Int = 1000) async throws -> InterlaceReport {
        let binary = try BinaryLocator.ffmpegURL()
        let result = try await ProcessRunner.run(
            executable: binary,
            arguments: [
                "-nostdin", "-hide_banner", "-nostats",
                "-i", url.path,
                "-an", "-vf", "idet",
                "-frames:v", "\(maxFrames)",
                "-f", "null", "-"
            ],
            throwOnNonZeroExit: false
        )
        return parseIdet(stderr: result.stderr)
    }

    static func parseIdet(stderr: String) -> InterlaceReport {
        // We trust the "Multi frame detection" line, which is the smoothed verdict.
        var report = InterlaceReport()
        let lines = stderr.split(whereSeparator: { $0.isNewline }).map(String.init)
        guard let multi = lines.last(where: { $0.contains("Multi frame detection") }) else {
            return report
        }
        report.tff = extractInt(in: multi, after: "TFF:") ?? 0
        report.bff = extractInt(in: multi, after: "BFF:") ?? 0
        report.progressive = extractInt(in: multi, after: "Progressive:") ?? 0
        report.undetermined = extractInt(in: multi, after: "Undetermined:") ?? 0
        return report
    }

    // MARK: - Letterbox / pillarbox (cropdetect)

    static func detectCrop(url: URL, sampleEvery: Int = 25, maxFrames: Int = 600) async throws -> CropReport? {
        let binary = try BinaryLocator.ffmpegURL()
        let filter = "select='not(mod(n\\,\(sampleEvery)))',cropdetect=24:16:0:0"
        let result = try await ProcessRunner.run(
            executable: binary,
            arguments: [
                "-nostdin", "-hide_banner", "-nostats",
                "-i", url.path,
                "-an", "-vf", filter,
                "-frames:v", "\(maxFrames)",
                "-f", "null", "-"
            ],
            throwOnNonZeroExit: false
        )
        return parseCropdetect(stderr: result.stderr)
    }

    static func parseCropdetect(stderr: String) -> CropReport? {
        // We want the most common crop=W:H:X:Y across all logged frames.
        var counts: [String: Int] = [:]
        var inW = 0
        var inH = 0
        for raw in stderr.split(whereSeparator: { $0.isNewline }) {
            let line = String(raw)
            guard line.contains("[Parsed_cropdetect") else { continue }
            if inW == 0 {
                inW = extractInt(in: line, after: "x2:").map { $0 + 1 } ?? 0
                inH = extractInt(in: line, after: "y2:").map { $0 + 1 } ?? 0
            }
            if let r = line.range(of: "crop=") {
                let rest = line[r.upperBound...]
                let token = rest.prefix(while: { $0.isNumber || $0 == ":" })
                counts[String(token), default: 0] += 1
            }
        }
        guard let (winner, _) = counts.max(by: { $0.value < $1.value }) else { return nil }
        let parts = winner.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 4, inW > 0, inH > 0 else { return nil }
        return CropReport(
            recommended: CropBox(w: parts[0], h: parts[1], x: parts[2], y: parts[3]),
            inputWidth: inW,
            inputHeight: inH
        )
    }

    // MARK: - Audio phase (aphasemeter)

    static func measureAudioPhase(
        url: URL,
        sourceLabel: String,
        leftSpec: String,
        rightSpec: String
    ) async throws -> AudioPhaseReport {
        let binary = try BinaryLocator.ffmpegURL()
        let result = try await ProcessRunner.run(
            executable: binary,
            arguments: [
                "-nostdin", "-hide_banner", "-nostats",
                "-i", url.path,
                "-filter_complex",
                "[\(leftSpec)][\(rightSpec)]amerge=inputs=2,aphasemeter=video=0:metadata=1",
                "-vn", "-f", "null", "-"
            ],
            throwOnNonZeroExit: false
        )
        var report = parseAphasemeter(stderr: result.stderr)
        report.sourceLabel = sourceLabel
        return report
    }

    static func parseAphasemeter(stderr: String) -> AudioPhaseReport {
        var phases: [Double] = []
        for raw in stderr.split(whereSeparator: { $0.isNewline }) {
            let line = String(raw)
            if let v = extractDouble(in: line, after: "lavfi.aphasemeter.phase=") {
                phases.append(v)
            }
        }
        guard !phases.isEmpty else { return AudioPhaseReport() }
        let mean = phases.reduce(0, +) / Double(phases.count)
        let antiPhase = Double(phases.filter { $0 < 0 }.count) / Double(phases.count)
        var report = AudioPhaseReport()
        report.meanPhase = mean
        report.minPhase = phases.min() ?? 0
        report.maxPhase = phases.max() ?? 0
        report.antiPhaseRatio = antiPhase
        return report
    }

    // MARK: - Audio stats (DC offset, peak, RMS)

    static func measureAudioStats(url: URL, streamSelector: String = "0:a:0") async throws -> AudioStatsReport {
        let binary = try BinaryLocator.ffmpegURL()
        let result = try await ProcessRunner.run(
            executable: binary,
            arguments: [
                "-nostdin", "-hide_banner", "-nostats",
                "-i", url.path,
                "-map", streamSelector,
                "-af", "astats=metadata=1:reset=0,ametadata=mode=print:file=-",
                "-vn", "-f", "null", "-"
            ],
            throwOnNonZeroExit: false
        )
        return parseAstats(stdout: result.stdout)
    }

    static func parseAstats(stdout: String) -> AudioStatsReport {
        var overallDC: Double = 0
        var peak: Double?
        var rms: Double?
        var perChannelDC: [Int: Double] = [:]
        for raw in stdout.split(whereSeparator: { $0.isNewline }) {
            let line = String(raw)
            if let v = extractDouble(in: line, after: "lavfi.astats.Overall.DC_offset=") {
                overallDC = v
            } else if let v = extractDouble(in: line, after: "lavfi.astats.Overall.Peak_level=") {
                peak = v
            } else if let v = extractDouble(in: line, after: "lavfi.astats.Overall.RMS_level=") {
                rms = v
            } else if let r = line.range(of: "lavfi.astats."),
                      line.contains(".DC_offset=") {
                let rest = line[r.upperBound...]
                let chanToken = rest.prefix(while: { $0 != "." })
                if let chanIdx = Int(chanToken),
                   let v = extractDouble(in: line, after: ".DC_offset=") {
                    perChannelDC[chanIdx] = v
                }
            }
        }
        var report = AudioStatsReport()
        report.overallDCOffset = overallDC
        report.peakLevelDB = peak
        report.rmsLevelDB = rms
        report.perChannelDCOffset = perChannelDC.sorted { $0.key < $1.key }.map(\.value)
        return report
    }

    // MARK: - Duplicate / dropped frames detection (mpdecimate)

    /// Pipes the file through `mpdecimate` (which drops duplicate frames) and
    /// compares the kept-frame count to the original input count to estimate
    /// how many frames were redundant.
    static func detectDuplicateFrames(
        url: URL,
        inputFrameCount: Int
    ) async throws -> DuplicateFramesReport {
        let binary = try BinaryLocator.ffmpegURL()
        let result = try await ProcessRunner.run(
            executable: binary,
            arguments: [
                "-nostdin", "-hide_banner",
                "-i", url.path,
                "-an", "-vf", "mpdecimate",
                "-progress", "-",
                "-f", "null", "-"
            ],
            throwOnNonZeroExit: false
        )
        let kept = parseMpdecimateKeptCount(stdout: result.stdout, stderr: result.stderr)
        return DuplicateFramesReport(inputFrameCount: inputFrameCount, keptFrameCount: kept)
    }

    /// `ffmpeg -progress -` writes `frame=N` lines to stdout. The very last
    /// occurrence before `progress=end` is the final kept-frame count.
    static func parseMpdecimateKeptCount(stdout: String, stderr: String) -> Int {
        var kept = 0
        for raw in stdout.split(whereSeparator: { $0.isNewline }) {
            let line = String(raw)
            if line.hasPrefix("frame=") {
                if let n = Int(line.dropFirst("frame=".count)) { kept = n }
            }
        }
        if kept > 0 { return kept }
        // Fallback: scrape the final summary on stderr.
        for raw in stderr.split(whereSeparator: { $0.isNewline }).reversed() {
            let line = String(raw)
            if let r = line.range(of: "frame=") {
                let rest = line[r.upperBound...]
                let token = rest.drop(while: { $0 == " " }).prefix(while: \.isNumber)
                if let n = Int(token), n > 0 { return n }
            }
        }
        return 0
    }

    // MARK: - Bars + tone leader (head leader analysis)

    /// Analyses the first `windowSec` seconds for SMPTE/EBU colour bars and a
    /// 1 kHz reference tone. Both heuristics are deliberately conservative —
    /// we'd rather miss a real leader than flag program content.
    static func analyzeLeader(url: URL, windowSec: Double = 30.0) async throws -> LeaderReport {
        async let bars = analyzeBarsWindow(url: url, windowSec: min(windowSec, 10.0))
        async let tone = analyzeToneWindow(url: url, windowSec: windowSec)
        var report = LeaderReport()
        let (b, t) = try await (bars, tone)
        report.barsDetected = b.detected
        report.barsConfidence = b.confidence
        report.barsDurationSec = b.durationSec
        report.toneDetected = t.detected
        report.toneConfidence = t.confidence
        report.toneLevelDBFS = t.levelDB
        return report
    }

    private struct BarsResult { var detected: Bool; var confidence: Double; var durationSec: Double }

    private static func analyzeBarsWindow(url: URL, windowSec: Double) async throws -> BarsResult {
        let binary = try BinaryLocator.ffmpegURL()
        let filter = "trim=duration=\(windowSec),signalstats=stat=satavg,metadata=mode=print:file=-"
        let result = try await ProcessRunner.run(
            executable: binary,
            arguments: [
                "-nostdin", "-hide_banner", "-nostats",
                "-i", url.path,
                "-an", "-vf", filter,
                "-f", "null", "-"
            ],
            throwOnNonZeroExit: false
        )
        // Bars: very high mean saturation and very stable luma. Collect per-frame
        // SATAVG and YAVG; classify a frame as "bars-like" when SATAVG > 50 (8-bit
        // scale 0–255). If >= 2 s of consecutive bars-like frames, declare leader.
        var samples: [(pts: Double, sat: Double, y: Double)] = []
        var pendingPts: Double = 0
        var pendingSat: Double?
        var pendingY: Double?
        for raw in result.stdout.split(whereSeparator: { $0.isNewline }) {
            let line = String(raw)
            if line.hasPrefix("frame:") {
                if let sat = pendingSat, let y = pendingY {
                    samples.append((pendingPts, sat, y))
                }
                pendingSat = nil; pendingY = nil
                if let r = line.range(of: "pts_time:") {
                    let token = line[r.upperBound...].prefix(while: { $0.isNumber || $0 == "." || $0 == "-" })
                    pendingPts = Double(token) ?? pendingPts
                }
            } else if let s = extractDouble(in: line, after: "lavfi.signalstats.SATAVG=") {
                pendingSat = s
            } else if let y = extractDouble(in: line, after: "lavfi.signalstats.YAVG=") {
                pendingY = y
            }
        }
        if let sat = pendingSat, let y = pendingY {
            samples.append((pendingPts, sat, y))
        }
        guard samples.count >= 2 else { return BarsResult(detected: false, confidence: 0, durationSec: 0) }

        // Window of consecutive frames where SATAVG > 50 and luma variance < 5.
        var bestRun: (start: Double, end: Double, meanSat: Double) = (0, 0, 0)
        var runStart: Double?
        var runSatSum: Double = 0
        var runCount: Int = 0
        var prevY: Double?
        for s in samples {
            let highSat = s.sat > 50
            let stableY = (prevY.map { abs(s.y - $0) < 5 } ?? true)
            if highSat && stableY {
                if runStart == nil { runStart = s.pts; runSatSum = 0; runCount = 0 }
                runSatSum += s.sat
                runCount += 1
                let dur = s.pts - (runStart ?? s.pts)
                if dur > (bestRun.end - bestRun.start) {
                    bestRun = (runStart!, s.pts, runSatSum / Double(max(1, runCount)))
                }
            } else {
                runStart = nil; runSatSum = 0; runCount = 0
            }
            prevY = s.y
        }
        let duration = bestRun.end - bestRun.start
        let confidence = min(1.0, max(0, (bestRun.meanSat - 50) / 80) * min(1.0, duration / 4.0))
        return BarsResult(detected: duration >= 2.0, confidence: confidence, durationSec: duration)
    }

    private struct ToneResult { var detected: Bool; var confidence: Double; var levelDB: Double? }

    private static func analyzeToneWindow(url: URL, windowSec: Double) async throws -> ToneResult {
        let binary = try BinaryLocator.ffmpegURL()
        // Branch the audio: one keeps full signal, the other keeps only ±50 Hz
        // around 1 kHz. RMS ratio between them reveals a pure tone.
        let filterComplex =
            "[0:a]atrim=duration=\(windowSec),asplit=2[a][b];" +
            "[a]astats=metadata=1:reset=1,ametadata=mode=print:file=-[full];" +
            "[b]bandpass=f=1000:width_type=h:w=80,astats=metadata=1:reset=1,ametadata=mode=print:file=-[band]"
        let result = try await ProcessRunner.run(
            executable: binary,
            arguments: [
                "-nostdin", "-hide_banner", "-nostats",
                "-i", url.path,
                "-filter_complex", filterComplex,
                "-map", "[full]", "-f", "null", "-",
                "-map", "[band]", "-f", "null", "-"
            ],
            throwOnNonZeroExit: false
        )
        // Both branches emit interleaved metadata, but RMS_level is the metric
        // we need. Bucket lines by their occurrence order: we expect roughly
        // equal numbers per branch. Easiest: take the mean RMS of each, by
        // counting which branch produced each (we don't have stream labels in
        // metadata output, so we just compute combined mean).
        var rmsValues: [Double] = []
        for raw in result.stdout.split(whereSeparator: { $0.isNewline }) {
            let line = String(raw)
            if let v = extractDouble(in: line, after: "lavfi.astats.Overall.RMS_level=") {
                rmsValues.append(v)
            }
        }
        guard !rmsValues.isEmpty else {
            return ToneResult(detected: false, confidence: 0, levelDB: nil)
        }
        // Half the values are from full, half from band — sort by absolute value
        // and compare the two halves' means.
        let sorted = rmsValues.sorted()
        let mid = sorted.count / 2
        let bandRMS = sorted.suffix(from: mid).reduce(0, +) / Double(sorted.count - mid)
        let fullRMS = sorted.prefix(mid).reduce(0, +) / Double(max(1, mid))
        let diffDB = bandRMS - fullRMS
        let confidence = max(0, min(1, (10 - abs(diffDB)) / 10))
        let detected = abs(diffDB) < 6 && bandRMS > -50
        return ToneResult(detected: detected, confidence: confidence,
                          levelDB: detected ? bandRMS : nil)
    }

    // MARK: - Audio pops / clicks

    /// Frame-level RMS comparison across the whole programme; any short window
    /// whose level jumps more than `jumpThresholdDB` from the previous one is
    /// flagged as a potential pop / click.
    static func detectAudioPops(url: URL,
                                jumpThresholdDB: Double = 6.0,
                                streamSelector: String = "0:a:0") async throws -> AudioPopsReport {
        let binary = try BinaryLocator.ffmpegURL()
        let result = try await ProcessRunner.run(
            executable: binary,
            arguments: [
                "-nostdin", "-hide_banner", "-nostats",
                "-i", url.path,
                "-map", streamSelector,
                "-af", "astats=metadata=1:reset=1:length=0.05,ametadata=mode=print:file=-",
                "-vn", "-f", "null", "-"
            ],
            throwOnNonZeroExit: false
        )
        var report = AudioPopsReport()
        var prevRMS: Double?
        var currentPts: Double = 0
        for raw in result.stdout.split(whereSeparator: { $0.isNewline }) {
            let line = String(raw)
            if line.hasPrefix("frame:") {
                if let r = line.range(of: "pts_time:") {
                    let token = line[r.upperBound...].prefix(while: { $0.isNumber || $0 == "." || $0 == "-" })
                    currentPts = Double(token) ?? currentPts
                }
            } else if let v = extractDouble(in: line, after: "lavfi.astats.Overall.RMS_level=") {
                if let prev = prevRMS {
                    let jump = abs(v - prev)
                    if jump >= jumpThresholdDB {
                        report.jumpCount += 1
                        if jump > report.biggestJumpDB {
                            report.biggestJumpDB = jump
                            report.biggestJumpTimeSec = currentPts
                        }
                        if report.events.count < 30 {
                            report.events.append(.init(timeSec: currentPts, jumpDB: jump))
                        }
                    }
                }
                prevRMS = v
            }
        }
        return report
    }

    // MARK: - Frozen frames detection

    static func detectFreeze(
        url: URL,
        noiseThresholdDB: Double = -60.0,
        minDurationSec: Double = 2.0
    ) async throws -> [TimeRange] {
        let binary = try BinaryLocator.ffmpegURL()
        let filter = "freezedetect=n=\(noiseThresholdDB)dB:d=\(minDurationSec)"
        let result = try await ProcessRunner.run(
            executable: binary,
            arguments: [
                "-nostdin", "-hide_banner", "-nostats",
                "-i", url.path,
                "-an", "-vf", filter,
                "-f", "null", "-"
            ],
            throwOnNonZeroExit: false
        )
        return parseFreezeDetect(stderr: result.stderr)
    }

    static func parseFreezeDetect(stderr: String) -> [TimeRange] {
        var pendingStart: Double?
        var ranges: [TimeRange] = []
        for raw in stderr.split(whereSeparator: { $0.isNewline }) {
            let line = String(raw)
            guard line.contains("[freezedetect") else { continue }
            if let s = extractDouble(in: line, after: "freeze_start: ") {
                pendingStart = s
            } else if let e = extractDouble(in: line, after: "freeze_end: "),
                      let s = pendingStart {
                ranges.append(TimeRange(startSec: s, endSec: e))
                pendingStart = nil
            }
        }
        return ranges
    }

    private static func extractInt(in line: String, after key: String) -> Int? {
        guard let r = line.range(of: key) else { return nil }
        var rest = Substring(line[r.upperBound...])
        while let first = rest.first, first.isWhitespace { rest = rest.dropFirst() }
        let token = rest.prefix(while: { ch in
            ch == "-" || ch.isNumber
        })
        return Int(token)
    }

    // MARK: - Parsers

    static func parseEBUR128(stderr: String, sourceLabel: String) -> LoudnessReport {
        var report = LoudnessReport(sourceLabel: sourceLabel)
        // Capture the *last* Summary block (filter prints intermediate samples).
        guard let summaryRange = stderr.range(of: "Summary:", options: .backwards) else {
            return report
        }
        let summary = stderr[summaryRange.lowerBound...]
        let lines = summary.split(whereSeparator: { $0.isNewline }).map(String.init)

        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if let v = scrape(line, prefix: "I:", suffix: "LUFS") { report.integratedLUFS = v }
            else if let v = scrape(line, prefix: "Threshold:", suffix: "LUFS"),
                    report.thresholdLUFS == nil { report.thresholdLUFS = v }
            else if let v = scrape(line, prefix: "LRA:", suffix: "LU") { report.loudnessRangeLU = v }
            else if let v = scrape(line, prefix: "Peak:", suffix: "dBFS") { report.truePeakDBTP = v }
            else if let v = scrape(line, prefix: "True peak:", suffix: "dBFS") { report.truePeakDBTP = v }
        }
        return report
    }

    private static func scrape(_ line: String, prefix: String, suffix: String) -> Double? {
        guard line.hasPrefix(prefix) else { return nil }
        var body = String(line.dropFirst(prefix.count))
        if let r = body.range(of: suffix) { body = String(body[..<r.lowerBound]) }
        body = body.trimmingCharacters(in: .whitespaces)
        return Double(body)
    }

    static func parseBlackDetect(stderr: String) -> [TimeRange] {
        var ranges: [TimeRange] = []
        for raw in stderr.split(whereSeparator: { $0.isNewline }) {
            let line = String(raw)
            guard line.contains("[blackdetect") else { continue }
            let start = extractDouble(in: line, after: "black_start:")
            let end = extractDouble(in: line, after: "black_end:")
            if let s = start, let e = end, e > s {
                ranges.append(TimeRange(startSec: s, endSec: e))
            }
        }
        return ranges
    }

    static func parseSilenceDetect(stderr: String) -> [TimeRange] {
        var pendingStart: Double?
        var ranges: [TimeRange] = []
        for raw in stderr.split(whereSeparator: { $0.isNewline }) {
            let line = String(raw)
            guard line.contains("[silencedetect") else { continue }
            if let s = extractDouble(in: line, after: "silence_start:") {
                pendingStart = s
            } else if let e = extractDouble(in: line, after: "silence_end:"),
                      let s = pendingStart {
                ranges.append(TimeRange(startSec: s, endSec: e))
                pendingStart = nil
            }
        }
        return ranges
    }

    private static func extractDouble(in line: String, after key: String) -> Double? {
        guard let r = line.range(of: key) else { return nil }
        var rest = Substring(line[r.upperBound...])
        while let first = rest.first, first.isWhitespace { rest = rest.dropFirst() }
        // Accept scientific notation: digits, dot, sign, and exponent marker.
        let token = rest.prefix(while: { ch in
            ch.isNumber || ch == "." || ch == "-" || ch == "+" || ch == "e" || ch == "E"
        })
        return Double(token)
    }
}
