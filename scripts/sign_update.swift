#!/usr/bin/env swift
// MisiQC Pro — Sparkle release signer
// ----------------------------------------------------------------------------
// Signs a .zip / .dmg with the Sparkle Ed25519 private key, in the exact
// format Sparkle expects in the appcast's sparkle:edSignature attribute.
//
// Usage:
//   swift scripts/sign_update.swift build/release/MisiQC-Pro-1.0.0.zip
//
// Prints:
//   sparkle:edSignature="<base64>" length="<bytes>"
//
// Append the printed attributes to the <enclosure> element of your appcast.xml.

import Foundation
import CryptoKit

guard CommandLine.arguments.count >= 2 else {
    print("Usage: swift scripts/sign_update.swift <file>")
    exit(1)
}

let fileURL = URL(fileURLWithPath: CommandLine.arguments[1])
guard let data = try? Data(contentsOf: fileURL) else {
    fputs("error: cannot read \(fileURL.path)\n", stderr); exit(1)
}

let scriptDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let privatePath = scriptDir
    .appendingPathComponent("output")
    .appendingPathComponent("sparkle_private_key.dat")
guard let keyData = try? Data(contentsOf: privatePath),
      let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: keyData) else {
    fputs("error: cannot load Sparkle private key at \(privatePath.path)\n", stderr); exit(1)
}

let signature = try key.signature(for: data)
let sigB64 = signature.base64EncodedString()
let length = data.count

print("sparkle:edSignature=\"\(sigB64)\" length=\"\(length)\"")
