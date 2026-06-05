import SwiftUI

/// Acidulated pastel palette used across the app.
enum Brand {
    // Logo gradient stops (electric sky → violet → candy pink).
    static let gradientStart = Color(red: 0.176, green: 0.847, blue: 1.000)   // #2DD8FF
    static let gradientMid   = Color(red: 0.443, green: 0.357, blue: 1.000)   // #715BFF
    static let gradientEnd   = Color(red: 1.000, green: 0.310, blue: 0.557)   // #FF4F8E

    // Per-channel accent (used in mode cards).
    static let francetv = Color(red: 0.318, green: 0.482, blue: 1.000)  // #517BFF
    static let m6       = Color(red: 1.000, green: 0.392, blue: 0.580)  // #FF6494
    static let tf1      = Color(red: 1.000, green: 0.561, blue: 0.243)  // #FF8F3E
    static let canalplus = Color(red: 0.580, green: 0.412, blue: 0.949) // #946AF2
    static let arte      = Color(red: 0.992, green: 0.690, blue: 0.000) // #FDB000 (jaune ARTE)
    static let netflix   = Color(red: 0.898, green: 0.071, blue: 0.118) // #E5121E
    static let amazon    = Color(red: 0.000, green: 0.659, blue: 0.835) // #00A8D5 (Prime cyan)
    static let disney    = Color(red: 0.067, green: 0.094, blue: 0.337) // #111856 (Disney+ navy)
    static let appletv   = Color(red: 0.000, green: 0.000, blue: 0.000) // noir Apple
    static let max       = Color(red: 0.000, green: 0.400, blue: 1.000) // #0066FF (HBO Max blue)
    static let paramount = Color(red: 0.000, green: 0.388, blue: 0.937) // #0063EF (Paramount blue)
    static let tv5monde  = Color(red: 0.929, green: 0.000, blue: 0.184) // #ED002F (rouge)
    static let france24  = Color(red: 0.871, green: 0.000, blue: 0.114) // #DE001D
    static let lequipe   = Color(red: 0.945, green: 0.812, blue: 0.000) // #F1CF00 (jaune)
    static let gulli     = Color(red: 0.945, green: 0.404, blue: 0.000) // #F16700 (orange Gulli)
    static let rtbf      = Color(red: 0.890, green: 0.114, blue: 0.176) // #E31D2D (rouge)
    static let ardzdf    = Color(red: 0.012, green: 0.122, blue: 0.345) // #031F58 (bleu sombre)
    static let rai       = Color(red: 0.012, green: 0.318, blue: 0.624) // #03519F
    static let bbc       = Color(red: 0.067, green: 0.067, blue: 0.067) // noir BBC
    static let dpp       = Color(red: 0.114, green: 0.400, blue: 0.620) // #1D669E (bleu DPP)
    static let youtube   = Color(red: 1.000, green: 0.000, blue: 0.000) // #FF0000 (rouge YT)
    static let vimeo     = Color(red: 0.106, green: 0.694, blue: 0.871) // #1BB1DE (cyan Vimeo)

    // Stat card tints (very pastel backgrounds).
    static let tintBlue   = Color(red: 0.886, green: 0.945, blue: 1.000) // #E2F1FF
    static let tintLilac  = Color(red: 0.941, green: 0.918, blue: 1.000) // #F0EAFF
    static let tintMint   = Color(red: 0.886, green: 0.973, blue: 0.929) // #E2F8ED
    static let tintPeach  = Color(red: 1.000, green: 0.929, blue: 0.871) // #FFEDDE

    // Stat card accents.
    static let accentBlue   = Color(red: 0.180, green: 0.475, blue: 0.960) // #2E79F5
    static let accentLilac  = Color(red: 0.490, green: 0.388, blue: 0.949) // #7D63F2
    static let accentMint   = Color(red: 0.118, green: 0.682, blue: 0.408) // #1EAE68
    static let accentPeach  = Color(red: 0.937, green: 0.510, blue: 0.114) // #EF821D
    static let tintRed     = Color(red: 1.000, green: 0.910, blue: 0.910) // #FFE8E8
    static let accentRed   = Color(red: 0.851, green: 0.196, blue: 0.196) // #D93232
}

extension Color {
    static let channel: (String) -> Color = { id in
        switch id {
        case "francetv": return Brand.francetv
        case "m6": return Brand.m6
        case "tf1": return Brand.tf1
        case "canalplus": return Brand.canalplus
        case "arte": return Brand.arte
        case "netflix": return Brand.netflix
        case "amazon": return Brand.amazon
        case "disney": return Brand.disney
        case "appletv": return Brand.appletv
        case "max": return Brand.max
        case "paramount": return Brand.paramount
        case "tv5monde": return Brand.tv5monde
        case "france24": return Brand.france24
        case "lequipe": return Brand.lequipe
        case "gulli": return Brand.gulli
        case "rtbf": return Brand.rtbf
        case "ardzdf": return Brand.ardzdf
        case "rai": return Brand.rai
        case "bbc": return Brand.bbc
        case "dpp": return Brand.dpp
        case "youtube": return Brand.youtube
        case "vimeo": return Brand.vimeo
        default: return .gray
        }
    }
}
