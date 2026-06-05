#!/usr/bin/env swift
// MisiQC Pro — License key generator
// ----------------------------------------------------------------------------
// Generates an Ed25519 signing key pair (one-shot, persisted on disk) and a
// batch of N license keys ready to upload to Payhip as a CSV.
//
// Usage:
//   swift scripts/generate_keys.swift            # default: 5000 keys
//   swift scripts/generate_keys.swift 1000       # custom count
//
// Outputs (in scripts/output/):
//   private_key.dat   — Ed25519 private key (KEEP SECRET, never commit)
//   public_key.dat    — Ed25519 public key
//   public_key.hex    — Hex string ready to paste into LicenseService.swift
//   keys.csv          — One license key per line, ready to upload to Payhip
//   keys.txt          — Same keys as a plain text list for manual inspection
//
// License key format (74 bytes binary, ~143 chars base32 with hyphens):
//   [0..1]   "M1" magic (0x4D 0x31)
//   [2..5]   Expiry (UInt32 BE, days since 2025-01-01)
//   [6..9]   Random nonce (UInt32)
//   [10..73] Ed25519 signature of bytes [0..9]
//
// Each key is *perpetual* — encoded expiry is 2125-01-01 (effectively a
// lifetime license). Verify offline in the app using the embedded public key.

import Foundation
import CryptoKit

// MARK: - Constants

let scriptDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let outputDir = scriptDir.appendingPathComponent("output")
try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

let privateKeyPath = outputDir.appendingPathComponent("private_key.dat")
let publicKeyPath  = outputDir.appendingPathComponent("public_key.dat")
let publicHexPath  = outputDir.appendingPathComponent("public_key.hex")
let csvPath        = outputDir.appendingPathComponent("keys.csv")
let txtPath        = outputDir.appendingPathComponent("keys.txt")

// MARK: - Args

let count: Int = {
    if CommandLine.arguments.count >= 2,
       let n = Int(CommandLine.arguments[1]), n > 0 { return n }
    return 5000
}()

// MARK: - Key pair (load existing or create)

let privateKey: Curve25519.Signing.PrivateKey
let publicKey:  Curve25519.Signing.PublicKey

if let existing = try? Data(contentsOf: privateKeyPath),
   let restored = try? Curve25519.Signing.PrivateKey(rawRepresentation: existing) {
    privateKey = restored
    publicKey  = restored.publicKey
    print("→ Reusing existing key pair at \(privateKeyPath.path)")
} else {
    privateKey = Curve25519.Signing.PrivateKey()
    publicKey  = privateKey.publicKey
    try privateKey.rawRepresentation.write(to: privateKeyPath)
    try publicKey.rawRepresentation.write(to: publicKeyPath)
    print("→ Generated new key pair")
    print("  - private: \(privateKeyPath.path)")
    print("  - public:  \(publicKeyPath.path)")
}

// Persist public key as a hex string (easy to paste into Swift source).
let publicHex = publicKey.rawRepresentation.map { String(format: "%02x", $0) }.joined()
try publicHex.write(to: publicHexPath, atomically: true, encoding: .utf8)

print("→ Public key (paste into LicenseService.publicKeyHex):")
print(publicHex)

// MARK: - Base32 (RFC 4648, no padding)

let alphabet: [Character] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")

func base32Encode(_ data: Data) -> String {
    var out = ""
    var buffer: UInt64 = 0
    var bits = 0
    for byte in data {
        buffer = (buffer << 8) | UInt64(byte)
        bits += 8
        while bits >= 5 {
            bits -= 5
            let idx = Int((buffer >> bits) & 0x1F)
            out.append(alphabet[idx])
        }
    }
    if bits > 0 {
        let idx = Int((buffer << (5 - bits)) & 0x1F)
        out.append(alphabet[idx])
    }
    return out
}

func chunk(_ s: String, every: Int) -> String {
    var result: [String] = []
    var current = ""
    for (i, ch) in s.enumerated() {
        current.append(ch)
        if (i + 1) % every == 0 {
            result.append(current); current = ""
        }
    }
    if !current.isEmpty { result.append(current) }
    return result.joined(separator: "-")
}

// MARK: - Build payload

let referenceDate: Date = {
    var c = DateComponents()
    c.year = 2025; c.month = 1; c.day = 1
    return Calendar(identifier: .iso8601).date(from: c)!
}()

func payload(expiryDays: UInt32, nonce: UInt32) -> Data {
    var bytes = Data(capacity: 10)
    bytes.append(0x4D); bytes.append(0x31)   // magic "M1"
    var ed = expiryDays.bigEndian
    withUnsafeBytes(of: &ed) { bytes.append(contentsOf: $0) }
    var nc = nonce.bigEndian
    withUnsafeBytes(of: &nc) { bytes.append(contentsOf: $0) }
    return bytes
}

func makeKey(expiryDate: Date) throws -> String {
    let daysSince = Int(expiryDate.timeIntervalSince(referenceDate) / 86_400)
    let expiryDays = UInt32(max(0, daysSince))
    let nonce = UInt32.random(in: 1...UInt32.max)
    let p = payload(expiryDays: expiryDays, nonce: nonce)
    let signature = try privateKey.signature(for: p)
    let combined = p + signature
    let encoded = base32Encode(combined)
    return chunk(encoded, every: 5)
}

// MARK: - Generate the batch

// Perpetual licence : encoded expiry = 2125-01-01. Effectively a lifetime
// license for any real-world user. The 32-bit days-since-2025 field can
// hold ~11 600 years so there's no overflow concern.
let perpetualExpiry: Date = {
    var c = DateComponents()
    c.year = 2125; c.month = 1; c.day = 1
    return Calendar(identifier: .iso8601).date(from: c)!
}()
print("→ Generating \(count) perpetual keys (encoded expiry: \(perpetualExpiry))")

var csvLines: [String] = ["license_key"]
var txtLines: [String] = []
for i in 1...count {
    let key = try makeKey(expiryDate: perpetualExpiry)
    csvLines.append(key)
    txtLines.append(key)
    if i % 1000 == 0 { print("  …\(i)/\(count)") }
}

try csvLines.joined(separator: "\n").write(to: csvPath, atomically: true, encoding: .utf8)
try txtLines.joined(separator: "\n").write(to: txtPath, atomically: true, encoding: .utf8)

print("✅ Done.")
print("  - CSV (upload to Payhip): \(csvPath.path)")
print("  - TXT (inspect)          : \(txtPath.path)")
print("  - Public key (hex)       : \(publicHexPath.path)")
print("")
print("Next steps:")
print("  1. Copy the public_key.hex contents into LicenseService.publicKeyHex.")
print("  2. Upload keys.csv into Payhip → Product → License keys → Upload list.")
print("  3. KEEP private_key.dat OUT OF GIT — losing it means you can't issue more keys for the same public key.")
