import Foundation

/// Top-level grouping of channel profiles shown in the sidebar.
enum ChannelCategory: String, CaseIterable, Identifiable {
    case television
    case platform
    case internet
    var id: String { rawValue }

    func localizedName(_ locale: AppLocale) -> String {
        switch self {
        case .television:
            switch locale {
            case .fr: return "Télévision"
            case .en: return "Television"
            case .es: return "Televisión"
            }
        case .platform:
            switch locale {
            case .fr: return "Plateformes"
            case .en: return "Platforms"
            case .es: return "Plataformas"
            }
        case .internet:
            switch locale {
            case .fr: return "Internet"
            case .en: return "Internet"
            case .es: return "Internet"
            }
        }
    }
}

/// Loads `ChannelSpec` JSON profiles from the app bundle's `Specs/` resources.
enum SpecRepository {

    /// Ordered IDs grouped by category — drives the sidebar layout.
    static let bundledByCategory: [(ChannelCategory, [String])] = [
        (.television, [
            // France
            "francetv", "france24", "tv5monde", "lequipe",
            "tf1", "tmc", "tfx", "lci",
            "m6", "w9", "sixter", "parispremiere", "gulli",
            "canalplus", "c8", "cnews",
            "bfmtv",
            // Europe ouest / centre
            "arte", "rtbf", "vrt", "ardzdf", "rtl", "prosieben",
            "npo", "srg", "orf",
            // Europe du Nord
            "nrk", "svt", "dr", "yle",
            // Europe du Sud
            "rai", "mediaset", "tve", "rtp", "tvp",
            // UK / Irlande
            "bbc", "itv", "channel4", "skyuk", "dpp",
            // Amérique du Nord
            "cbc", "tva", "pbs", "nbc", "cbs", "abc", "fox",
            // Sport / Info internationaux
            "eurosport", "dazn", "aljazeera", "dw", "euronews"
        ]),
        (.platform, [
            "netflix", "amazon", "disney", "appletv", "max", "paramount",
            "hulu", "peacock", "mubi", "crunchyroll", "pluto", "tubi", "britbox"
        ]),
        (.internet, [
            "youtube", "vimeo",
            "tiktok", "instagram", "twitch", "facebook", "linkedin"
        ])
    ]

    /// Flat list — used for the AppState and default-profile lookup.
    static var bundledIDs: [String] {
        bundledByCategory.flatMap { $0.1 }
    }

    static func loadAll() -> [ChannelSpec] {
        bundledIDs.compactMap { try? load(id: $0) }
    }

    static func load(id: String) throws -> ChannelSpec {
        let url = try resourceURL(for: id)
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ChannelSpec.self, from: data)
    }

    private static func resourceURL(for id: String) throws -> URL {
        if let url = Bundle.main.url(forResource: id, withExtension: "json", subdirectory: "Specs") {
            return url
        }
        if let url = Bundle.main.url(forResource: id, withExtension: "json") {
            return url
        }
        throw NSError(domain: "SpecRepository", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "Profil '\(id)' introuvable dans le bundle."])
    }
}
