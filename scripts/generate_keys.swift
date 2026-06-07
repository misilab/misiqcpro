#!/usr/bin/env swift
// MisiQC Pro — License key generator (format M2, HMAC-SHA256)
// ----------------------------------------------------------------------------
// Generates an HMAC-SHA256 secret (one-shot, persisted on disk) and a batch of
// N license keys ready to upload to Payhip as a CSV.
//
// Usage:
//   swift scripts/generate_keys.swift            # default: 7000 keys
//   swift scripts/generate_keys.swift 1000       # custom count
//
// Outputs (in scripts/output/):
//   hmac_secret.dat   — HMAC-SHA256 secret (32 bytes, KEEP SECRET, never commit)
//   hmac_secret.hex   — Hex string ready to paste into LicenseService.swift
//   keys.csv          — One license key per line, ready to upload to Payhip
//   keys.txt          — Same keys as a plain text list for manual inspection
//
// License key format M2 (25 bytes binary, 40 chars base32, 47 with hyphens):
//   [0..1]   "M2" magic (0x4D 0x32)
//   [2..5]   Expiry (UInt32 BE, days since 2025-01-01)
//   [6..8]   Random nonce (3 bytes)
//   [9..24]  HMAC-SHA256(payload[0..8]) truncated to 16 bytes
//
// Each key is *perpetual* — encoded expiry is 2125-01-01 (effectively a
// lifetime license). Verify offline in the app using the embedded HMAC secret.

import Foundation
import CryptoKit

// MARK: - Paths

let scriptDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let outputDir = scriptDir.appendingPathComponent("output")
try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

let secretPath    = outputDir.appendingPathComponent("hmac_secret.dat")
let secretHexPath = outputDir.appendingPathComponent("hmac_secret.hex")
let csvPath       = outputDir.appendingPathComponent("keys.csv")
let txtPath       = outputDir.appendingPathComponent("keys.txt")

// MARK: - Args

let count: Int = {
    if CommandLine.arguments.count >= 2,
       let n = Int(CommandLine.arguments[1]), n > 0 { return n }
    return 7000
}()

// MARK: - HMAC secret (load existing or create)

let secret: SymmetricKey
if let existing = try? Data(contentsOf: secretPath), existing.count == 32 {
    secret = SymmetricKey(data: existing)
    print("→ Reusing existing HMAC secret at \(secretPath.path)")
} else {
    secret = SymmetricKey(size: .bits256)
    let data = secret.withUnsafeBytes { Data($0) }
    try data.write(to: secretPath)
    print("→ Generated new HMAC secret")
    print("  - secret: \(secretPath.path)")
}

let secretHex = secret.withUnsafeBytes { Data($0) }
    .map { String(format: "%02x", $0) }.joined()
try secretHex.write(to: secretHexPath, atomically: true, encoding: .utf8)
print("→ HMAC secret (paste into LicenseService.hmacSecretHex):")
print(secretHex)

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
            out.append(alphabet[Int((buffer >> bits) & 0x1F)])
        }
    }
    if bits > 0 {
        out.append(alphabet[Int((buffer << (5 - bits)) & 0x1F)])
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

// MARK: - Payload + key construction

let referenceDate: Date = {
    var c = DateComponents()
    c.year = 2025; c.month = 1; c.day = 1
    return Calendar(identifier: .iso8601).date(from: c)!
}()

func makePayload(expiryDays: UInt32, nonce: Data) -> Data {
    precondition(nonce.count == 3)
    var bytes = Data(capacity: 9)
    bytes.append(0x4D); bytes.append(0x32)        // magic "M2"
    var ed = expiryDays.bigEndian
    withUnsafeBytes(of: &ed) { bytes.append(contentsOf: $0) }
    bytes.append(nonce)
    return bytes
}

func makeKey(expiryDate: Date) -> String {
    let daysSince = Int(expiryDate.timeIntervalSince(referenceDate) / 86_400)
    let expiryDays = UInt32(max(0, daysSince))
    var nonce = Data(count: 3)
    for i in 0..<3 { nonce[i] = UInt8.random(in: 0...255) }
    let payload = makePayload(expiryDays: expiryDays, nonce: nonce)
    let mac = HMAC<SHA256>.authenticationCode(for: payload, using: secret)
    let macData = Data(mac).prefix(16)
    let combined = payload + macData       // 25 bytes
    return chunk(base32Encode(combined), every: 5)
}

// MARK: - Generate the batch

// Perpetual licence : encoded expiry = 2125-01-01.
let perpetualExpiry: Date = {
    var c = DateComponents()
    c.year = 2125; c.month = 1; c.day = 1
    return Calendar(identifier: .iso8601).date(from: c)!
}()
print("→ Generating \(count) perpetual M2 keys (encoded expiry: \(perpetualExpiry))")

var csvLines: [String] = ["license_key"]
var txtLines: [String] = []
for i in 1...count {
    let key = makeKey(expiryDate: perpetualExpiry)
    csvLines.append(key)
    txtLines.append(key)
    if i % 1000 == 0 { print("  …\(i)/\(count)") }
}

try csvLines.joined(separator: "\n").write(to: csvPath, atomically: true, encoding: .utf8)
try txtLines.joined(separator: "\n").write(to: txtPath, atomically: true, encoding: .utf8)

print("✅ Done.")
print("  - CSV (upload to Payhip): \(csvPath.path)")
print("  - TXT (inspect)          : \(txtPath.path)")
print("  - HMAC secret (hex)      : \(secretHexPath.path)")
print("")
print("Next steps:")
print("  1. Copy hmac_secret.hex contents into LicenseService.hmacSecretHex.")
print("  2. Upload keys.csv into Payhip → Product → License keys → Upload list.")
print("  3. KEEP hmac_secret.dat OUT OF GIT — losing it means you can't issue more keys.")
