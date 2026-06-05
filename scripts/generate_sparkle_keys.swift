#!/usr/bin/env swift
// MisiQC Pro — Sparkle EdDSA key pair generator
// ----------------------------------------------------------------------------
// Generates an Ed25519 key pair for signing Sparkle updates. Different from
// the licence keys (those are signed separately).
//
// Usage:
//   swift scripts/generate_sparkle_keys.swift
//
// Outputs (in scripts/output/):
//   sparkle_private_key.dat   — Ed25519 private key (KEEP SECRET, never commit)
//   sparkle_public_key.b64    — base64 public key, ready to paste into Info.plist
//                                under the SUPublicEDKey key

import Foundation
import CryptoKit

let scriptDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let outputDir = scriptDir.appendingPathComponent("output")
try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

let privatePath = outputDir.appendingPathComponent("sparkle_private_key.dat")
let publicPath  = outputDir.appendingPathComponent("sparkle_public_key.b64")

if FileManager.default.fileExists(atPath: privatePath.path) {
    print("⚠️  Sparkle key pair already exists at \(privatePath.path)")
    print("    Refusing to overwrite — delete the file first if you really want a new pair")
    print("    (regenerating invalidates every released appcast signature).")
    exit(1)
}

let priv = Curve25519.Signing.PrivateKey()
let pub  = priv.publicKey

try priv.rawRepresentation.write(to: privatePath)
let pubB64 = pub.rawRepresentation.base64EncodedString()
try pubB64.write(to: publicPath, atomically: true, encoding: .utf8)

print("✅ Sparkle key pair generated.")
print("  private: \(privatePath.path) — KEEP SECRET")
print("  public : \(publicPath.path)")
print("")
print("Public key (paste into Info.plist as SUPublicEDKey):")
print(pubB64)
