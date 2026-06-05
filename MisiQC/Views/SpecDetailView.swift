import SwiftUI

/// Read-only viewer that shows every field of a `ChannelSpec` in a readable
/// form, grouped by category. Opened from the left column.
struct SpecDetailView: View {
    let spec: ChannelSpec
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var state

    private func t(_ key: L10n.Key) -> String { state.t(key) }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    confidenceBanner

                    section(t(.specHeaderContainer), icon: "shippingbox") {
                        row(t(.specFormat),
                            spec.video.acceptedContainers?.map(\.localizedUppercase).joined(separator: " / ")
                                  ?? spec.video.container?.uppercased())
                        row(t(.specOperationalPattern), spec.video.operationalPattern)
                        row(t(.specShim), spec.video.shim)
                    }

                    section(t(.specHeaderVideo), icon: "film") {
                        row(t(.specCodec),
                            spec.video.acceptedCodecs?.joined(separator: " / ") ?? spec.video.codec)
                        row(t(.specProfile), spec.video.profile)
                        row(t(.specResolution),
                            spec.video.acceptedResolutions?.map(\.displayString).joined(separator: " / ")
                                  ?? spec.video.resolution?.displayString)
                        row(t(.specFramerate),
                            spec.video.acceptedFramerates?.map { "\($0.displayString) fps" }.joined(separator: " / ")
                            ?? spec.video.framerate.map { "\($0.displayString) fps" })
                        row(t(.specInterlace),
                            spec.video.interlaced.map { $0 ? t(.interlaced) : t(.progressive) })
                        row(t(.specFieldOrder), spec.video.fieldOrder)
                        if let br = spec.video.bitrate {
                            row(t(.specBitrate), br.displayString + " bps")
                            row(t(.specBitrateMode), spec.video.bitrateMode)
                        }
                        if let g = spec.video.gopSize { row(t(.specGOP), "\(g)") }
                        if let closed = spec.video.gopClosed {
                            row(t(.specGOPClosed), closed ? t(.yes) : t(.no))
                        }
                        row(t(.specColorSpace),
                            spec.video.acceptedColorSpaces?.joined(separator: " / ") ?? spec.video.colorSpace)
                        row(t(.specColorPrimaries),
                            spec.video.acceptedColorPrimaries?.joined(separator: " / ") ?? spec.video.colorPrimaries)
                        row(t(.specColorTransfer),
                            spec.video.acceptedColorTransfers?.joined(separator: " / ") ?? spec.video.colorTransfer)
                        row(t(.specColorRange), spec.video.colorRange.map(rangeDisplay))
                        row(t(.specAspectRatio), spec.video.aspectRatio)
                    }

                    section(t(.specHeaderAudio), icon: "waveform") {
                        row(t(.specAudioCodec), spec.audio.codec)
                        row(t(.specAudioBitDepth), spec.audio.bitDepth.map { "\($0) bits" })
                        row(t(.specAudioSampleRate), spec.audio.sampleRate.map { "\($0) Hz" })
                        row(t(.specAcceptedTracks),
                            spec.audio.acceptedTrackCounts?.map(String.init).joined(separator: " / "))

                        if let mapping = spec.audio.channelMapping, !mapping.isEmpty {
                            ForEach(mapping.keys.sorted(), id: \.self) { variant in
                                let tracks = mapping[variant] ?? []
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(t(.specMappingPrefix)) \(variant)")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.secondary)
                                    ForEach(tracks.sorted(by: { $0.index < $1.index }), id: \.index) { trk in
                                        HStack(spacing: 6) {
                                            Text("T\(trk.index)")
                                                .frame(width: 26, alignment: .leading)
                                                .font(.caption.monospaced())
                                            Text(roleLabel(trk.role))
                                                .font(.caption)
                                            if let n = trk.note {
                                                Text("— \(n)")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                        }
                                    }
                                }
                                .padding(8)
                                .background(Color.secondary.opacity(0.06),
                                            in: RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }

                    if let loud = spec.loudness {
                        section(t(.specHeaderLoudness), icon: "speaker.wave.3") {
                            if let target = loud.integratedTarget {
                                row(t(.specIntegratedLUFS), target.displayString + " LUFS")
                            }
                            if let tp = loud.maxTruePeak {
                                row(t(.specMaxTruePeak), String(format: "%.1f dBTP", tp))
                            }
                            if let lra = loud.maxLRA {
                                row(t(.specMaxLRA), String(format: "%.1f LU", lra))
                            }
                            if let st = loud.maxShortTerm {
                                row(t(.specMaxShortTerm), String(format: "%.1f LUFS", st))
                            }
                        }
                    }

                    section(t(.specHeaderStructure), icon: "timer") {
                        row(t(.specTCStart), spec.structure.timecodeStart)
                        if let df = spec.structure.dropFrame {
                            row(t(.specDropFrame), df ? t(.yes) : t(.no))
                        }
                        if let nb = spec.structure.maxBlackDurationSec {
                            row(t(.specMaxBlack), String(format: "%.1f s", nb))
                        }
                        if let ns = spec.structure.maxSilenceDurationSec {
                            row(t(.specMaxSilence), String(format: "%.1f s", ns))
                        }
                        if let noSlate = spec.structure.noSlateAllowed {
                            row(t(.specSlate),
                                noSlate ? t(.specSlateForbidden) : t(.specSlateAllowed))
                        }
                    }

                    if let doc = spec.documentReference {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(t(.specReference))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                            Text(doc)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 540, idealWidth: 620, minHeight: 600, idealHeight: 720)
    }

    private var header: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.channel(spec.id).opacity(0.18))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "tv")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.channel(spec.id))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(spec.name)
                    .font(.system(size: 17, weight: .heavy))
                Text(spec.specVersion)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
        }
        .padding(16)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, icon: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 11, weight: .bold))
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(0.6)
            }
            .foregroundStyle(Color.channel(spec.id))
            VStack(alignment: .leading, spacing: 5) {
                content()
            }
            .padding(12)
            .background(Color(nsColor: .textBackgroundColor),
                        in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.secondary.opacity(0.14), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            HStack(alignment: .top, spacing: 8) {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 150, alignment: .leading)
                Text(value)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func roleLabel(_ role: AudioTrackRole.Role) -> String {
        switch role {
        case .vfLeft:  return "VF — L"
        case .vfRight: return "VF — R"
        case .voLeft:  return "VO — L"
        case .voRight: return "VO — R"
        case .adLeft:  return "Audio Description — L"
        case .adRight: return "Audio Description — R"
        case .silence: return "Silence codé"
        case .dolbyE_L: return "Dolby E — L"
        case .dolbyE_R: return "Dolby E — R"
        }
    }

    private func rangeDisplay(_ raw: String) -> String {
        switch raw.lowercased() {
        case "tv", "legal", "narrow", "limited": return "Video Range (legal)"
        case "pc", "full":                       return "Full Range"
        default: return raw
        }
    }

    @ViewBuilder private var confidenceBanner: some View {
        let conf = spec.confidence
        let tint: Color = {
            switch conf {
            case .verified: return Color(red: 0.118, green: 0.682, blue: 0.408)
            case .standard: return Color(red: 0.180, green: 0.475, blue: 0.960)
            case .generic:  return Color(red: 0.937, green: 0.510, blue: 0.114)
            }
        }()
        let icon: String = {
            switch conf {
            case .verified: return "checkmark.seal.fill"
            case .standard: return "doc.badge.gearshape.fill"
            case .generic:  return "exclamationmark.triangle.fill"
            }
        }()
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(tint)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(conf.localizedLabel(state.locale).uppercased())
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(0.6)
                    .foregroundStyle(tint)
                Text(conf.longExplanation(state.locale))
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(tint.opacity(0.35), lineWidth: 1)
        )
    }
}
