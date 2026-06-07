import Foundation
import CryptoKit
import Observation

/// Owns the licence + trial state and persists it across launches.
/// Verifies licence keys offline using an embedded HMAC-SHA256 secret.
///
/// Key format M2 (25 bytes total, encoded as base32 RFC 4648 with hyphens,
/// final string is 47 characters = 8 groups of 5 separated by `-`):
///   • [0..1]   "M2" magic (0x4D 0x32)
///   • [2..5]   Expiry: UInt32 BE = days since 2025-01-01
///   • [6..8]   Random nonce (3 bytes — uniqueness across the batch)
///   • [9..24]  HMAC-SHA256(payload[0..8]) truncated to 16 bytes
///
/// The HMAC secret lives only on the seller's machine (scripts/output/).
@Observable
@MainActor
final class LicenseService {

    // MARK: - Public state

    private(set) var status: LicenseStatus = .trial(daysLeft: trialLengthDays)

    /// Computer name shown in the trial banner and the PDF watermark.
    let hostName: String = Host.current().localizedName ?? Host.current().name ?? "Mac"

    // MARK: - Configuration

    static let trialLengthDays = 7

    /// Embedded HMAC-SHA256 secret — produced by `scripts/generate_keys.swift`.
    /// MUST match the secret used to sign distributed licence keys.
    /// Replace this hex string after regenerating the secret (you generally
    /// should never need to — keep the same secret across versions).
    private static let hmacSecretHex =
        "e40566d46e424147408eb2f88b8dc4bcb5453db3956331a37e9bea2341d0bfb9"

    /// Reference date used by the generator + verifier — must stay in sync
    /// with `scripts/generate_keys.swift`.
    private static let referenceDate: Date = {
        var c = DateComponents()
        c.year = 2025; c.month = 1; c.day = 1
        return Calendar(identifier: .iso8601).date(from: c)!
    }()

    private static let keyMagic: [UInt8] = [0x4D, 0x32]   // "M2"
    private static let payloadSize = 9                    // magic + expiry + nonce
    private static let macSize     = 16                   // truncated HMAC
    private static let keySize     = 25                   // 9 + 16
    private static let keychainAccount = "license_key"
    private static let firstLaunchKey = "license.firstLaunchDate"

    // MARK: - Init

    init() {
        refresh()
    }

    /// Re-evaluates status from disk: existing licence (Keychain) first,
    /// trial period (UserDefaults) as fallback, then expired.
    func refresh() {
        if let stored = KeychainHelper.read(account: Self.keychainAccount),
           case .success(let validated) = validate(stored) {
            status = .licensed(expiry: validated.expiry,
                               fingerprint: fingerprint(of: stored))
            return
        }
        let firstLaunch: Date = {
            if let v = UserDefaults.standard.object(forKey: Self.firstLaunchKey) as? Date {
                return v
            }
            let now = Date()
            UserDefaults.standard.set(now, forKey: Self.firstLaunchKey)
            return now
        }()
        let used = Int(Date().timeIntervalSince(firstLaunch) / 86_400)
        let left = max(0, Self.trialLengthDays - used)
        status = left > 0 ? .trial(daysLeft: left) : .expired
    }

    // MARK: - Activation

    @discardableResult
    func activate(rawKey: String) -> Result<Date, LicenseError> {
        let result = validate(rawKey)
        switch result {
        case .success(let v):
            KeychainHelper.save(rawKey.uppercased(), for: Self.keychainAccount)
            status = .licensed(expiry: v.expiry,
                               fingerprint: fingerprint(of: rawKey))
            return .success(v.expiry)
        case .failure(let e):
            return .failure(e)
        }
    }

    /// Removes the current licence and reverts to trial / expired state.
    func deactivate() {
        KeychainHelper.delete(account: Self.keychainAccount)
        refresh()
    }

    // MARK: - Validation

    private struct ValidatedKey { let expiry: Date }

    private func validate(_ raw: String) -> Result<ValidatedKey, LicenseError> {
        // Keep only valid base32 characters. Tolerant of hyphens, whitespace,
        // \r, NBSP, tabs, zero-width chars and other paste artefacts.
        let stripped = String(raw.uppercased().filter { Self.base32Alphabet.contains($0) })
        guard let data = base32Decode(stripped) else {
            return .failure(.malformedKey(actualLength: stripped.count))
        }
        guard data.count == Self.keySize else {
            return .failure(.malformedKey(actualLength: stripped.count))
        }
        guard data[0] == Self.keyMagic[0], data[1] == Self.keyMagic[1] else {
            return .failure(.unsupportedVersion)
        }

        let payload = data.prefix(Self.payloadSize)
        let receivedMac = data.suffix(Self.macSize)

        guard let secretBytes = Self.hexToBytes(Self.hmacSecretHex) else {
            return .failure(.invalidSignature)
        }
        let key = SymmetricKey(data: secretBytes)
        let expectedFull = HMAC<SHA256>.authenticationCode(for: payload, using: key)
        let expectedMac = Data(expectedFull).prefix(Self.macSize)
        guard Self.constantTimeEqual(receivedMac, expectedMac) else {
            return .failure(.invalidSignature)
        }

        // Decode expiry days (bytes 2..5, big-endian UInt32).
        let expiryBytes = data[2..<6]
        let expiryDays = expiryBytes.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        let expiry = Self.referenceDate.addingTimeInterval(TimeInterval(expiryDays) * 86_400)
        if expiry < Date() { return .failure(.keyExpired(expiry)) }
        return .success(ValidatedKey(expiry: expiry))
    }

    /// Constant-time byte comparison to avoid timing leaks during HMAC check.
    private static func constantTimeEqual<A: Collection, B: Collection>(_ a: A, _ b: B)
        -> Bool where A.Element == UInt8, B.Element == UInt8 {
        guard a.count == b.count else { return false }
        var diff: UInt8 = 0
        for (x, y) in zip(a, b) { diff |= (x ^ y) }
        return diff == 0
    }

    // MARK: - Fingerprint (5-char prefix shown in UI & watermark)

    private func fingerprint(of rawKey: String) -> String {
        let cleaned = String(rawKey.uppercased().filter { Self.base32Alphabet.contains($0) })
        return String(cleaned.prefix(5))
    }

    /// Convenience accessor for the watermark.
    var licenseFingerprint: String? {
        if case .licensed(_, let f) = status { return f }
        return nil
    }

    /// True when the licence expiry is ≥ 30 years away — treated as perpetual
    /// in the UI ("Licence à vie") instead of showing a far-future date.
    static func isPerpetual(_ expiry: Date) -> Bool {
        let years = Calendar.current.dateComponents([.year], from: Date(), to: expiry).year ?? 0
        return years >= 30
    }

    // MARK: - Base32 decoder (RFC 4648)

    private static let base32Alphabet =
        Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")

    private func base32Decode(_ s: String) -> Data? {
        var buffer: UInt64 = 0
        var bits = 0
        var out = Data()
        for ch in s {
            guard let idx = Self.base32Alphabet.firstIndex(of: ch) else { return nil }
            buffer = (buffer << 5) | UInt64(idx)
            bits += 5
            if bits >= 8 {
                bits -= 8
                out.append(UInt8((buffer >> bits) & 0xFF))
            }
        }
        return out
    }

    // MARK: - Hex helper

    private static func hexToBytes(_ hex: String) -> Data? {
        var out = Data()
        var idx = hex.startIndex
        while idx < hex.endIndex {
            let next = hex.index(idx, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
            guard let byte = UInt8(hex[idx..<next], radix: 16) else { return nil }
            out.append(byte)
            idx = next
        }
        return out
    }
}
