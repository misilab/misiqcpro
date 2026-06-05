#!/usr/bin/env swift
// MisiQC Pro — Logo / icon renderer
// ---------------------------------------------------------------------------
// Re-generates the full macOS AppIcon set + a large standalone logo PNG, all
// from the same Core Graphics drawing as `DesignSystem/BrandLogo.swift`. Run
// after tweaking the gradient or stroke to refresh every asset in one pass.
//
// Usage:
//   swift scripts/render_logo.swift
//
// Outputs:
//   MisiQC/Assets.xcassets/AppIcon.appiconset/icon_*.png   (full AppIcon set)
//   scripts/output/MisiQC-Logo-1024.png                    (standalone HD logo)
//   scripts/output/MisiQC-Logo-1024-transparent.png        (HD logo on transparent BG)

import Foundation
import AppKit

let projectRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent()
let appIconDir = projectRoot
    .appendingPathComponent("MisiQC/Assets.xcassets/AppIcon.appiconset")
let outputDir = projectRoot
    .appendingPathComponent("scripts/output")
try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

// MARK: - Drawing

func render(pixelSize: Int, transparentBackground: Bool = false) -> Data? {
    let size = CGFloat(pixelSize)
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize, pixelsHigh: pixelSize,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 4 * pixelSize, bitsPerPixel: 32
    ) else { return nil }

    NSGraphicsContext.saveGraphicsState()
    guard let nsCtx = NSGraphicsContext(bitmapImageRep: bitmap) else {
        NSGraphicsContext.restoreGraphicsState(); return nil
    }
    NSGraphicsContext.current = nsCtx
    let ctx = nsCtx.cgContext

    let radius: CGFloat = transparentBackground ? 0 : size * 0.225
    let bgPath = CGPath(roundedRect: CGRect(x: 0, y: 0, width: size, height: size),
                        cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.saveGState()
    ctx.addPath(bgPath); ctx.clip()

    if !transparentBackground {
        let colorspace = CGColorSpaceCreateDeviceRGB()
        // Slightly punchier stops than BrandLogo: stronger blue + deeper pink.
        let colors = [
            CGColor(red: 0.157, green: 0.788, blue: 1.000, alpha: 1),  // brighter blue
            CGColor(red: 0.404, green: 0.298, blue: 1.000, alpha: 1),  // saturated violet
            CGColor(red: 1.000, green: 0.224, blue: 0.494, alpha: 1)   // deeper pink
        ] as CFArray
        let gradient = CGGradient(colorsSpace: colorspace, colors: colors,
                                  locations: [0, 0.55, 1])!
        ctx.drawLinearGradient(gradient,
                               start: CGPoint(x: 0, y: size),
                               end: CGPoint(x: size, y: 0),
                               options: [])
        // Soft top highlight (gives the rounded-square that liquid-glass sheen).
        let hl = CGGradient(colorsSpace: colorspace, colors: [
            CGColor(red: 1, green: 1, blue: 1, alpha: 0.40),
            CGColor(red: 1, green: 1, blue: 1, alpha: 0)
        ] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(hl,
                               start: CGPoint(x: 0, y: size),
                               end: CGPoint(x: 0, y: size * 0.5),
                               options: [])
        // Subtle inner border for definition at small sizes.
        ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.18))
        ctx.setLineWidth(size * 0.008)
        ctx.stroke(CGRect(x: 0, y: 0, width: size, height: size))
    }
    ctx.restoreGState()

    // Waveform → checkmark stroke.
    let lineWidth = size * 0.115
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.setLineWidth(lineWidth)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x * size, y: (1.0 - y) * size)
    }
    let amp: CGFloat = 0.085
    let yMid: CGFloat = 0.50
    ctx.beginPath()
    ctx.move(to: p(0.12, yMid))
    ctx.addQuadCurve(to: p(0.22, yMid), control: p(0.17, yMid - amp))
    ctx.addQuadCurve(to: p(0.32, yMid), control: p(0.27, yMid + amp))
    ctx.addQuadCurve(to: p(0.42, yMid), control: p(0.37, yMid - amp))
    ctx.addLine(to: p(0.53, 0.72))
    ctx.addLine(to: p(0.86, 0.28))
    ctx.strokePath()

    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])
}

// MARK: - Write helpers

func write(_ data: Data, to url: URL) {
    do { try data.write(to: url); print("  ✓ \(url.lastPathComponent)") }
    catch { print("  ✗ \(url.lastPathComponent) — \(error)") }
}

// MARK: - Full AppIcon set

print("→ Re-rendering AppIcon set at \(appIconDir.path)")
let appIconSizes: [(name: String, px: Int)] = [
    ("icon_16.png",      16),
    ("icon_16@2x.png",   32),
    ("icon_32.png",      32),
    ("icon_32@2x.png",   64),
    ("icon_128.png",     128),
    ("icon_128@2x.png",  256),
    ("icon_256.png",     256),
    ("icon_256@2x.png",  512),
    ("icon_512.png",     512),
    ("icon_512@2x.png",  1024)
]
for (name, px) in appIconSizes {
    guard let data = render(pixelSize: px) else { continue }
    write(data, to: appIconDir.appendingPathComponent(name))
}

// MARK: - Standalone HD logos (for marketing, README, About panel, etc.)

print("→ Rendering 1024×1024 standalone logos")
if let withBG = render(pixelSize: 1024) {
    write(withBG, to: outputDir.appendingPathComponent("MisiQC-Logo-1024.png"))
}
if let transparent = render(pixelSize: 1024, transparentBackground: true) {
    write(transparent, to: outputDir.appendingPathComponent("MisiQC-Logo-1024-transparent.png"))
}

print("✅ Done. Reboot the Dock to refresh the icon:")
print("    killall Dock")
