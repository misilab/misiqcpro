import Foundation

/// Root data model for a TV channel PAD specification.
/// One JSON file per channel under `Resources/Specs/`.
struct ChannelSpec: Codable, Identifiable, Hashable {
    var id: String          // "francetv", "m6", "tf1", "canalplus"
    var name: String        // "France TV"
    var specVersion: String // "Annexe CDE 2023-01"
    var documentReference: String?
    /// Confidence level for the spec values. Defaults to `.generic` when the
    /// JSON omits it — explicit `.verified` / `.standard` must be opt-in.
    var confidence: SpecConfidence = .generic

    var video: VideoSpec
    var audio: AudioSpec
    var loudness: LoudnessSpec?
    var structure: StructureSpec

    enum CodingKeys: String, CodingKey {
        case id, name, specVersion, documentReference, confidence
        case video, audio, loudness, structure
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        specVersion = try c.decode(String.self, forKey: .specVersion)
        documentReference = try c.decodeIfPresent(String.self, forKey: .documentReference)
        confidence = try c.decodeIfPresent(SpecConfidence.self, forKey: .confidence) ?? .generic
        video = try c.decode(VideoSpec.self, forKey: .video)
        audio = try c.decode(AudioSpec.self, forKey: .audio)
        loudness = try c.decodeIfPresent(LoudnessSpec.self, forKey: .loudness)
        structure = try c.decode(StructureSpec.self, forKey: .structure)
    }
}

/// Trust level of a `ChannelSpec` — drives a visible badge in the UI so the
/// user knows whether to fully trust the values or cross-check with the
/// channel's official PDF.
enum SpecConfidence: String, Codable, CaseIterable {
    /// Official PDF read end-to-end — values trusted.
    case verified
    /// Built from a published industry standard (EBU R128/R103, AS-10/AS-11,
    /// CST RT-040, DPP, ATSC A/85, iTunes Package…).
    case standard
    /// Generic template, not cross-checked against the channel's current PDF.
    case generic

    func localizedLabel(_ locale: AppLocale) -> String {
        switch self {
        case .verified:
            switch locale {
            case .fr: return "Vérifié"; case .en: return "Verified"; case .es: return "Verificado"
            }
        case .standard:
            switch locale {
            case .fr: return "Standard"; case .en: return "Standard"; case .es: return "Estándar"
            }
        case .generic:
            switch locale {
            case .fr: return "Générique"; case .en: return "Generic"; case .es: return "Genérico"
            }
        }
    }

    func longExplanation(_ locale: AppLocale) -> String {
        switch self {
        case .verified:
            switch locale {
            case .fr: return "Profil construit à partir du PDF officiel de la chaîne. Valeurs fiables."
            case .en: return "Built from the channel's official PDF. Values trusted."
            case .es: return "Construido a partir del PDF oficial. Valores fiables."
            }
        case .standard:
            switch locale {
            case .fr: return "Basé sur un standard public (EBU, CST, DPP, ATSC) — fiable mais à recouper avec le contrat."
            case .en: return "Based on a public standard (EBU, CST, DPP, ATSC) — trustworthy but cross-check the contract."
            case .es: return "Basado en estándar público (EBU, CST, DPP, ATSC) — confiar pero verificar contrato."
            }
        case .generic:
            switch locale {
            case .fr: return "Profil générique non vérifié contre le PDF officiel actuel. À valider avec le diffuseur avant livraison contractuelle."
            case .en: return "Generic profile not checked against the current official PDF. Validate with the broadcaster before contractual delivery."
            case .es: return "Perfil genérico no verificado contra el PDF oficial actual. Validar con el emisor antes de la entrega contractual."
            }
        }
    }
}

struct VideoSpec: Codable, Hashable {
    var container: String?         // "mxf"
    /// Multiple acceptable containers (e.g. ["mxf", "mov"]). Takes priority over `container`.
    var acceptedContainers: [String]?
    var operationalPattern: String? // "OP1a"
    var shim: String?              // "AS-10 HIGH_HD_2014", "RDD9"
    var codec: String?             // "mpeg2video"
    /// Multiple acceptable codecs (e.g. ["jpeg2000", "prores"]). Takes priority over `codec`.
    var acceptedCodecs: [String]?
    var profile: String?           // "422P@HL"
    var resolution: Resolution?
    /// Multiple acceptable resolutions. Takes priority over `resolution`.
    var acceptedResolutions: [Resolution]?
    var framerate: RationalRate?
    /// Multiple acceptable frame rates (e.g. 23976/1000, 24/1, 25/1). Takes priority over `framerate`.
    var acceptedFramerates: [RationalRate]?
    var interlaced: Bool?
    var fieldOrder: String?        // "tt" (top first), "bb" (bottom first), "progressive"
    var bitrate: Tolerance?        // in bits/sec
    var bitrateMode: String?       // "CBR", "VBR"
    var gopSize: Int?
    var gopClosed: Bool?
    var colorSpace: String?        // matrix: "bt709", "bt2020nc"…
    /// Multiple acceptable matrix coefficients. Takes priority over `colorSpace`.
    var acceptedColorSpaces: [String]?
    var colorPrimaries: String?    // "bt709", "bt2020", "smpte170m"
    var acceptedColorPrimaries: [String]?
    var colorTransfer: String?     // EOTF / gamma curve: "bt709", "smpte2084" (PQ), "arib-std-b67" (HLG)
    var acceptedColorTransfers: [String]?
    /// Expected video range: "tv" (legal / narrow, e.g. 16-235 for 8-bit) or
    /// "pc" (full, 0-255). For broadcast deliveries this is almost always "tv".
    var colorRange: String?
    var aspectRatio: String?       // "16:9"
    /// True if the channel requires HDR static metadata (Mastering Display + MaxCLL/FALL).
    var requiresHDRMetadata: Bool?
    /// True if the channel requires AFD (Active Format Description) flag.
    var requiresAFD: Bool?
}

struct Resolution: Codable, Hashable {
    var width: Int
    var height: Int
    var displayString: String { "\(width)x\(height)" }
}

struct AudioSpec: Codable, Hashable {
    var codec: String?         // "pcm_s24le"
    var bitDepth: Int?         // 24
    var sampleRate: Int?       // 48000
    /// Accepted number of mono tracks. Channels are mono per track in broadcast MXF.
    var acceptedTrackCounts: [Int]?
    /// Raw mapping stored as `[String: [...]]` so JSONDecoder produces an object;
    /// access through `mapping(for:)` to retrieve via `VersionVariant`.
    var channelMapping: [String: [AudioTrackRole]]?

    func mapping(for variant: VersionVariant) -> [AudioTrackRole]? {
        channelMapping?[variant.rawValue]
    }

    var availableVariants: [VersionVariant] {
        (channelMapping?.keys ?? [:].keys).compactMap(VersionVariant.init(rawValue:))
    }
}

enum VersionVariant: String, Codable, CaseIterable, Identifiable {
    case vfOnly = "VF"
    case vfVO = "VF+VO"
    case vfAD = "VF+AD"
    case vfVOAD = "VF+VO+AD"
    var id: String { rawValue }
    var displayString: String { rawValue }
}

/// Role of a single mono track at a given index.
struct AudioTrackRole: Codable, Hashable {
    var index: Int           // 1-based to match broadcast convention
    var role: Role
    var note: String?

    enum Role: String, Codable {
        case vfLeft, vfRight
        case voLeft, voRight
        case adLeft, adRight
        case silence
        case dolbyE_L, dolbyE_R
    }
}

struct LoudnessSpec: Codable, Hashable {
    var integratedTarget: Tolerance?   // LUFS, e.g. -23 ± 1
    var maxTruePeak: Double?           // dBTP, e.g. -3
    var maxLRA: Double?                // LU, e.g. 20
    var maxShortTerm: Double?          // LUFS, for short programs
}

struct StructureSpec: Codable, Hashable {
    var timecodeStart: String?         // "00:00:00:00" / "10:00:00:00"
    var dropFrame: Bool?
    /// Reject if a single black segment exceeds this duration (seconds).
    var maxBlackDurationSec: Double?
    /// Reject if a single silence segment exceeds this duration (seconds).
    var maxSilenceDurationSec: Double?
    /// Forbid amorces / slate before first useful frame.
    var noSlateAllowed: Bool?
    /// True if the channel requires a SMPTE/EBU bars + 1 kHz tone leader at head.
    var requiresLeader: Bool?
    /// True if the channel requires embedded closed captions / subtitles.
    var requiresSubtitles: Bool?
    /// Minimum trailing black duration at the end of the programme (seconds).
    var minPostRollSec: Double?
}
