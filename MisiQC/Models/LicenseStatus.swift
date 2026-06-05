import Foundation

/// Top-level licensing state of the app.
enum LicenseStatus: Hashable {
    /// Trial period in progress — `daysLeft` ≥ 0.
    case trial(daysLeft: Int)
    /// Licence valid until `expiry`.
    case licensed(expiry: Date, fingerprint: String)
    /// Trial expired and no valid licence registered.
    case expired

    var isLicensed: Bool {
        if case .licensed = self { return true }
        return false
    }
    var isTrial: Bool {
        if case .trial = self { return true }
        return false
    }
    var isExpired: Bool {
        if case .expired = self { return true }
        return false
    }

    /// Whether the user can still use premium features (export PDF/CSV).
    /// During the trial they can; once expired they can't.
    var allowsExports: Bool { !isExpired }
}

/// Errors raised when activating a licence key.
enum LicenseError: LocalizedError {
    case malformedKey
    case invalidSignature
    case keyExpired(Date)
    case unsupportedVersion

    var errorDescription: String? {
        switch self {
        case .malformedKey:        return "Clé mal formée."
        case .invalidSignature:    return "Signature invalide — clé corrompue ou falsifiée."
        case .keyExpired(let d):   return "Clé expirée le \(d.formatted(date: .abbreviated, time: .omitted))."
        case .unsupportedVersion:  return "Format de clé non reconnu — mise à jour de l'app requise."
        }
    }
}
