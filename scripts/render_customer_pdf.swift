#!/usr/bin/env swift
// MisiQC Pro — Trilingual user manual PDF renderer (FR / EN / ES)
// ---------------------------------------------------------------------------
// Generates the customer-facing user manual: installation, activation, full
// interface tour, all 72 channel profiles, the analysis pipeline, the QC
// report, exports, settings, support — in three languages back-to-back.
//
// Usage:
//   swift scripts/render_customer_pdf.swift            # uses fallback version
//   swift scripts/render_customer_pdf.swift 1.0.5      # explicit version
//
// Output:
//   scripts/output/MisiQC-Pro-Manuel.pdf

import Foundation
import AppKit

let projectRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent()
let outputDir = projectRoot.appendingPathComponent("scripts/output")
try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
let pdfURL = outputDir.appendingPathComponent("MisiQC-Pro-Manuel.pdf")

let appVersion: String = {
    if CommandLine.arguments.count >= 2 {
        let raw = CommandLine.arguments[1].trimmingCharacters(in: .whitespacesAndNewlines)
        if !raw.isEmpty { return raw }
    }
    return "1.0.4"
}()

// MARK: - Brand colours

let gradientStart = NSColor(calibratedRed: 0.157, green: 0.788, blue: 1.000, alpha: 1)
let gradientMid   = NSColor(calibratedRed: 0.404, green: 0.298, blue: 1.000, alpha: 1)
let gradientEnd   = NSColor(calibratedRed: 1.000, green: 0.224, blue: 0.494, alpha: 1)
let accentBlue    = NSColor(calibratedRed: 0.180, green: 0.475, blue: 0.960, alpha: 1)
let accentMint    = NSColor(calibratedRed: 0.118, green: 0.682, blue: 0.408, alpha: 1)
let accentPeach   = NSColor(calibratedRed: 0.937, green: 0.510, blue: 0.114, alpha: 1)
let accentViolet  = NSColor(calibratedRed: 0.522, green: 0.341, blue: 0.937, alpha: 1)
let primaryText   = NSColor(calibratedWhite: 0.13, alpha: 1)
let secondaryText = NSColor(calibratedWhite: 0.45, alpha: 1)
let mutedBG       = NSColor(calibratedWhite: 0.97, alpha: 1)
let mutedBorder   = NSColor(calibratedWhite: 0.86, alpha: 1)
let dividerColor  = NSColor(calibratedWhite: 0.88, alpha: 1)

let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)   // A4 portrait @ 72 dpi
let margin: CGFloat = 48
let contentWidth = pageRect.width - margin * 2

// MARK: - PDF context

let data = NSMutableData()
guard let consumer = CGDataConsumer(data: data) else { exit(1) }
var mediaBox = pageRect
guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { exit(1) }
let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)

// MARK: - Element model

enum Element {
    case h2(String)                                     // subsection heading
    case p(String)                                      // paragraph
    case bullets([String])
    case numbered([String])
    case card(title: String?, body: String, accent: NSColor)
    case keyValueTable([(String, String)])              // 2-col label/value table
    case codeBlock(String)
    case divider
    case spacer(CGFloat)
    case columnedList(headline: String, items: [String], columns: Int)
}

struct ManualSection {
    let number: Int
    let title: String
    let elements: [Element]
}

enum Lang: String, CaseIterable { case fr, en, es }

// MARK: - Drawing primitives

func drawString(_ s: String, at point: CGPoint, font: NSFont,
                color: NSColor = primaryText, maxWidth: CGFloat? = nil,
                align: NSTextAlignment = .natural) {
    let style = NSMutableParagraphStyle()
    style.lineBreakMode = .byWordWrapping
    style.alignment = align
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font, .foregroundColor: color, .paragraphStyle: style
    ]
    if let maxWidth {
        // In a non-flipped CG context, NSString.draw(in:) renders the first
        // line at the TOP of the rect. We treat `point.y` as the desired TOP
        // edge of the text block — so position the rect so its top edge is
        // at point.y. That requires measuring the height first.
        let h = (s as NSString).boundingRect(
            with: CGSize(width: maxWidth, height: 5000),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs).height.rounded(.up) + 2
        let rect = CGRect(x: point.x, y: point.y - h, width: maxWidth, height: h)
        (s as NSString).draw(in: rect, withAttributes: attrs)
    } else {
        (s as NSString).draw(at: point, withAttributes: attrs)
    }
}

func boundsOf(_ s: String, font: NSFont, width: CGFloat,
              lineHeight: CGFloat? = nil) -> CGFloat {
    let style = NSMutableParagraphStyle()
    style.lineBreakMode = .byWordWrapping
    if let lh = lineHeight {
        style.minimumLineHeight = lh
        style.maximumLineHeight = lh
    }
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .paragraphStyle: style]
    return ceil((s as NSString).boundingRect(
        with: CGSize(width: width, height: 5000),
        options: [.usesLineFragmentOrigin, .usesFontLeading],
        attributes: attrs).height) + 2
}

@discardableResult
func drawWrapped(_ s: String, x: CGFloat, topY: CGFloat, width: CGFloat,
                 font: NSFont, color: NSColor, lineHeight: CGFloat) -> CGFloat {
    let style = NSMutableParagraphStyle()
    style.lineBreakMode = .byWordWrapping
    style.minimumLineHeight = lineHeight
    style.maximumLineHeight = lineHeight
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font, .foregroundColor: color, .paragraphStyle: style
    ]
    let h = boundsOf(s, font: font, width: width, lineHeight: lineHeight)
    let rect = CGRect(x: x, y: topY - h, width: width, height: h)
    (s as NSString).draw(in: rect, withAttributes: attrs)
    return h
}

// MARK: - Brand logo (mirrors DesignSystem/BrandLogo)

func brandLogoImage(pixelSize: Int) -> NSImage {
    let size = CGFloat(pixelSize)
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixelSize, pixelsHigh: pixelSize,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 4 * pixelSize, bitsPerPixel: 32
    ) else { return NSImage(size: NSSize(width: 1, height: 1)) }
    NSGraphicsContext.saveGraphicsState()
    guard let nsCtx = NSGraphicsContext(bitmapImageRep: bitmap) else {
        NSGraphicsContext.restoreGraphicsState()
        return NSImage(size: NSSize(width: 1, height: 1))
    }
    NSGraphicsContext.current = nsCtx
    let ctx = nsCtx.cgContext
    let radius = size * 0.225
    let bgPath = CGPath(roundedRect: CGRect(x: 0, y: 0, width: size, height: size),
                        cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.saveGState(); ctx.addPath(bgPath); ctx.clip()
    let cs = CGColorSpaceCreateDeviceRGB()
    let colors = [
        CGColor(red: 0.157, green: 0.788, blue: 1.0, alpha: 1),
        CGColor(red: 0.404, green: 0.298, blue: 1.0, alpha: 1),
        CGColor(red: 1.0,   green: 0.224, blue: 0.494, alpha: 1)
    ] as CFArray
    let g = CGGradient(colorsSpace: cs, colors: colors, locations: [0, 0.55, 1])!
    ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: size),
                           end: CGPoint(x: size, y: 0), options: [])
    let hl = CGGradient(colorsSpace: cs, colors: [
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.4),
        CGColor(red: 1, green: 1, blue: 1, alpha: 0)
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(hl, start: CGPoint(x: 0, y: size),
                           end: CGPoint(x: 0, y: size * 0.5), options: [])
    ctx.restoreGState()
    let lw = size * 0.105
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.setLineWidth(lw); ctx.setLineCap(.round); ctx.setLineJoin(.round)
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x * size, y: (1.0 - y) * size)
    }
    let amp: CGFloat = 0.085, yMid: CGFloat = 0.50
    ctx.beginPath()
    ctx.move(to: p(0.12, yMid))
    ctx.addQuadCurve(to: p(0.22, yMid), control: p(0.17, yMid - amp))
    ctx.addQuadCurve(to: p(0.32, yMid), control: p(0.27, yMid + amp))
    ctx.addQuadCurve(to: p(0.42, yMid), control: p(0.37, yMid - amp))
    ctx.addLine(to: p(0.53, 0.72))
    ctx.addLine(to: p(0.86, 0.28))
    ctx.strokePath()
    NSGraphicsContext.restoreGraphicsState()
    let img = NSImage(size: NSSize(width: size, height: size))
    img.addRepresentation(bitmap)
    return img
}

func drawBrandLogo(in rect: CGRect) {
    let px = max(64, Int(rect.width * 4))
    brandLogoImage(pixelSize: px)
        .draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
}

// MARK: - Page flow state

var currentY: CGFloat = pageRect.height
var totalPageCount: Int = 0
var currentFooterLabel: String = "MisiQC Pro"
var currentLangCode: String = "FR"

func startNewPage(footerLabel: String, langCode: String) {
    ctx.beginPDFPage(nil)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsCtx
    totalPageCount += 1
    currentFooterLabel = footerLabel
    currentLangCode = langCode
    currentY = pageRect.height - margin
    drawRunningHeader()
}

func endCurrentPage() {
    drawFooter(label: currentFooterLabel, pageNumber: totalPageCount)
    NSGraphicsContext.restoreGraphicsState()
    ctx.endPDFPage()
}

func drawRunningHeader() {
    // Top subtle strip: lang chip + product name
    let f = NSFont.systemFont(ofSize: 8.5, weight: .heavy)
    let chip = currentLangCode.uppercased()
    let chipSize = (chip as NSString).size(withAttributes: [.font: f])
    let chipPad: CGFloat = 6
    let chipW = chipSize.width + chipPad * 2
    let chipH: CGFloat = 16
    let chipRect = CGRect(x: margin, y: pageRect.height - margin + 8,
                          width: chipW, height: chipH)
    accentBlue.withAlphaComponent(0.15).setFill()
    NSBezierPath(roundedRect: chipRect, xRadius: chipH/2, yRadius: chipH/2).fill()
    drawString(chip,
               at: CGPoint(x: chipRect.minX + chipPad,
                           y: chipRect.midY - chipSize.height/2 + 1),
               font: f, color: accentBlue)
    drawString("MisiQC Pro · Manuel",
               at: CGPoint(x: chipRect.maxX + 8, y: chipRect.midY - 5),
               font: .systemFont(ofSize: 9, weight: .semibold),
               color: secondaryText)
}

func drawFooter(label: String, pageNumber: Int) {
    let footer = "MisiQC Pro v\(appVersion) · \(label) · contact@misiraca.com · \(pageNumber)"
    let f = NSFont.systemFont(ofSize: 8, weight: .medium)
    let w = (footer as NSString).size(withAttributes: [.font: f]).width
    drawString(footer,
               at: CGPoint(x: (pageRect.width - w) / 2, y: 18),
               font: f, color: secondaryText)
    dividerColor.setStroke()
    let sep = NSBezierPath()
    sep.move(to: CGPoint(x: margin, y: 36))
    sep.line(to: CGPoint(x: pageRect.width - margin, y: 36))
    sep.lineWidth = 0.4
    sep.stroke()
}

let bottomMargin: CGFloat = 56

func ensureSpace(_ needed: CGFloat) {
    if currentY - needed < bottomMargin {
        endCurrentPage()
        startNewPage(footerLabel: currentFooterLabel, langCode: currentLangCode)
    }
}

// MARK: - Element renderers

func renderH2(_ text: String) {
    let font = NSFont.systemFont(ofSize: 14, weight: .heavy)
    let lh: CGFloat = 18
    let h = boundsOf(text, font: font, width: contentWidth - 14, lineHeight: lh)
    ensureSpace(h + 22)
    currentY -= 10
    // Accent stripe on the left, full height of the heading text
    accentBlue.setFill()
    NSBezierPath(roundedRect: CGRect(x: margin, y: currentY - h, width: 4, height: h),
                 xRadius: 2, yRadius: 2).fill()
    drawWrapped(text, x: margin + 12, topY: currentY, width: contentWidth - 14,
                font: font, color: primaryText, lineHeight: lh)
    currentY -= h + 8
}

func renderP(_ text: String) {
    let font = NSFont.systemFont(ofSize: 10.5)
    let lh: CGFloat = 14
    let h = boundsOf(text, font: font, width: contentWidth, lineHeight: lh)
    ensureSpace(h + 6)
    drawWrapped(text, x: margin, topY: currentY, width: contentWidth,
                font: font, color: primaryText, lineHeight: lh)
    currentY -= h + 6
}

func renderBullets(_ items: [String], numbered: Bool = false) {
    let font = NSFont.systemFont(ofSize: 10.5)
    let lh: CGFloat = 14
    for (i, item) in items.enumerated() {
        let leader = numbered ? "\(i + 1)." : "•"
        let leaderFont: NSFont = numbered
            ? .systemFont(ofSize: 10.5, weight: .heavy)
            : .systemFont(ofSize: 12, weight: .bold)
        let textWidth = contentWidth - 20
        let h = boundsOf(item, font: font, width: textWidth, lineHeight: lh)
        ensureSpace(h + 5)
        drawString(leader, at: CGPoint(x: margin + 4, y: currentY - 12),
                   font: leaderFont, color: accentBlue)
        drawWrapped(item, x: margin + 18, topY: currentY, width: textWidth,
                    font: font, color: primaryText, lineHeight: lh)
        currentY -= h + 3
    }
    currentY -= 3
}

func renderCard(title: String?, body: String, accent: NSColor) {
    let innerWidth = contentWidth - 28
    let bodyFont = NSFont.systemFont(ofSize: 10.5)
    let bh = boundsOf(body, font: bodyFont, width: innerWidth, lineHeight: 14)
    let th: CGFloat = (title != nil) ? 18 : 0
    let pad: CGFloat = 12
    let total = th + bh + pad * 2
    ensureSpace(total + 8)
    let rect = CGRect(x: margin, y: currentY - total,
                      width: contentWidth, height: total)
    mutedBG.setFill()
    NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7).fill()
    mutedBorder.setStroke()
    let bp = NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7)
    bp.lineWidth = 0.4
    bp.stroke()
    accent.withAlphaComponent(0.95).setFill()
    NSBezierPath(rect: CGRect(x: rect.minX, y: rect.minY,
                              width: 3, height: rect.height)).fill()
    var cy = rect.maxY - pad
    if let title = title {
        drawString(title,
                   at: CGPoint(x: rect.minX + pad + 6, y: cy - 12),
                   font: .systemFont(ofSize: 11, weight: .heavy),
                   color: accent)
        cy -= th
    }
    drawWrapped(body, x: rect.minX + pad + 6, topY: cy,
                width: innerWidth - 6, font: bodyFont,
                color: primaryText, lineHeight: 14)
    currentY = rect.minY - 8
}

func renderKVTable(_ rows: [(String, String)]) {
    let labelFont = NSFont.systemFont(ofSize: 10, weight: .semibold)
    let valueFont = NSFont.systemFont(ofSize: 10)
    let lh: CGFloat = 14
    let labelWidth: CGFloat = 175
    let valueWidth = contentWidth - labelWidth - 12
    for (i, (label, value)) in rows.enumerated() {
        let lh1 = boundsOf(label, font: labelFont, width: labelWidth, lineHeight: lh)
        let lh2 = boundsOf(value, font: valueFont, width: valueWidth, lineHeight: lh)
        let rowH = max(lh1, lh2) + 6
        ensureSpace(rowH)
        if i % 2 == 0 {
            mutedBG.withAlphaComponent(0.6).setFill()
            NSBezierPath(rect: CGRect(x: margin, y: currentY - rowH,
                                      width: contentWidth, height: rowH)).fill()
        }
        drawWrapped(label, x: margin + 6, topY: currentY - 3, width: labelWidth,
                    font: labelFont, color: primaryText, lineHeight: lh)
        drawWrapped(value, x: margin + labelWidth + 12, topY: currentY - 3,
                    width: valueWidth, font: valueFont,
                    color: primaryText, lineHeight: lh)
        currentY -= rowH
    }
    currentY -= 4
}

func renderCode(_ text: String) {
    let font = NSFont.monospacedSystemFont(ofSize: 9, weight: .regular)
    let lh: CGFloat = 12
    let pad: CGFloat = 10
    let innerWidth = contentWidth - pad * 2
    let h = boundsOf(text, font: font, width: innerWidth, lineHeight: lh)
    ensureSpace(h + pad * 2 + 6)
    let rect = CGRect(x: margin, y: currentY - (h + pad * 2),
                      width: contentWidth, height: h + pad * 2)
    NSColor(calibratedWhite: 0.94, alpha: 1).setFill()
    NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5).fill()
    drawWrapped(text, x: rect.minX + pad, topY: rect.maxY - pad, width: innerWidth,
                font: font, color: primaryText, lineHeight: lh)
    currentY = rect.minY - 6
}

func renderDivider() {
    ensureSpace(12)
    dividerColor.setStroke()
    let line = NSBezierPath()
    line.move(to: CGPoint(x: margin + 50, y: currentY - 4))
    line.line(to: CGPoint(x: pageRect.width - margin - 50, y: currentY - 4))
    line.lineWidth = 0.5
    line.stroke()
    currentY -= 14
}

func renderSpacer(_ height: CGFloat) {
    ensureSpace(height)
    currentY -= height
}

func renderColumned(headline: String, items: [String], columns: Int) {
    let hlFont = NSFont.systemFont(ofSize: 11, weight: .heavy)
    let itemFont = NSFont.systemFont(ofSize: 9.5)
    let lh: CGFloat = 12
    let gutter: CGFloat = 12
    let colWidth = (contentWidth - gutter * CGFloat(columns - 1)) / CGFloat(columns)
    // Compute total height needed
    let perCol = (items.count + columns - 1) / columns
    let rowH: CGFloat = lh + 2
    let blockH = CGFloat(perCol) * rowH + 24
    ensureSpace(blockH)
    drawString(headline, at: CGPoint(x: margin, y: currentY - 12),
               font: hlFont, color: primaryText)
    currentY -= 22
    let startY = currentY
    for (idx, item) in items.enumerated() {
        let col = idx % columns
        let row = idx / columns
        let x = margin + (colWidth + gutter) * CGFloat(col)
        let y = startY - CGFloat(row) * rowH
        let chip = "·"
        drawString(chip,
                   at: CGPoint(x: x, y: y - lh + 2),
                   font: .systemFont(ofSize: 11, weight: .bold), color: accentBlue)
        drawString(item,
                   at: CGPoint(x: x + 8, y: y - lh + 2),
                   font: itemFont, color: primaryText)
    }
    currentY = startY - CGFloat(perCol) * rowH - 6
}

func render(_ e: Element) {
    switch e {
    case .h2(let s):              renderH2(s)
    case .p(let s):               renderP(s)
    case .bullets(let l):         renderBullets(l)
    case .numbered(let l):        renderBullets(l, numbered: true)
    case .card(let t, let b, let a): renderCard(title: t, body: b, accent: a)
    case .keyValueTable(let r):   renderKVTable(r)
    case .codeBlock(let s):       renderCode(s)
    case .divider:                renderDivider()
    case .spacer(let h):          renderSpacer(h)
    case .columnedList(let hl, let it, let c):
        renderColumned(headline: hl, items: it, columns: c)
    }
}

// MARK: - Cover page

func drawCoverPage(lang: Lang, strings: LangStrings) {
    startNewPage(footerLabel: strings.footerLabel, langCode: lang.rawValue)
    // Full-page hero band
    let bandH: CGFloat = 320
    let bandRect = CGRect(x: 0, y: pageRect.height - bandH,
                          width: pageRect.width, height: bandH)
    let cs = CGColorSpaceCreateDeviceRGB()
    let grad = CGGradient(colorsSpace: cs, colors: [
        gradientStart.cgColor, gradientMid.cgColor, gradientEnd.cgColor
    ] as CFArray, locations: [0, 0.55, 1])!
    ctx.saveGState()
    ctx.addRect(bandRect); ctx.clip()
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: bandRect.maxY),
                           end: CGPoint(x: bandRect.width, y: bandRect.minY),
                           options: [])
    ctx.restoreGState()

    let logoSize: CGFloat = 110
    let logoY = bandRect.maxY - 50 - logoSize
    drawBrandLogo(in: CGRect(x: margin, y: logoY,
                             width: logoSize, height: logoSize))
    drawString("MisiQC Pro",
               at: CGPoint(x: margin + logoSize + 22, y: logoY + logoSize - 50),
               font: .systemFont(ofSize: 38, weight: .heavy), color: .white)
    drawString(strings.subtitle,
               at: CGPoint(x: margin + logoSize + 22, y: logoY + logoSize - 78),
               font: .systemFont(ofSize: 14, weight: .medium),
               color: NSColor(calibratedWhite: 1, alpha: 0.92),
               maxWidth: contentWidth - logoSize - 22)
    drawString("v\(appVersion)",
               at: CGPoint(x: margin + logoSize + 22, y: logoY + logoSize - 100),
               font: .systemFont(ofSize: 12, weight: .heavy),
               color: NSColor(calibratedWhite: 1, alpha: 0.7))
    // Lang chip
    let chipFont = NSFont.systemFont(ofSize: 13, weight: .heavy)
    let chipText = lang.rawValue.uppercased()
    let chipSize = (chipText as NSString).size(withAttributes: [.font: chipFont])
    let chipPad: CGFloat = 12, chipH: CGFloat = 28
    let chipW = chipSize.width + chipPad * 2
    let chipRect = CGRect(x: pageRect.width - margin - chipW,
                          y: bandRect.maxY - 38 - chipH,
                          width: chipW, height: chipH)
    NSColor(calibratedWhite: 1, alpha: 0.22).setFill()
    NSBezierPath(roundedRect: chipRect, xRadius: chipH/2, yRadius: chipH/2).fill()
    drawString(chipText, at: CGPoint(x: chipRect.minX + chipPad,
                                     y: chipRect.midY - chipSize.height/2 + 1),
               font: chipFont, color: .white)
    // Welcome paragraph
    drawString(strings.welcome,
               at: CGPoint(x: margin, y: bandRect.minY + 32),
               font: .systemFont(ofSize: 13, weight: .medium),
               color: NSColor(calibratedWhite: 1, alpha: 0.92),
               maxWidth: contentWidth)
    // Below the band: short intro + TOC start
    currentY = bandRect.minY - 36
    drawString(strings.coverIntroTitle,
               at: CGPoint(x: margin, y: currentY - 14),
               font: .systemFont(ofSize: 16, weight: .heavy),
               color: primaryText)
    currentY -= 26
    drawWrapped(strings.coverIntroBody, x: margin, topY: currentY,
                width: contentWidth,
                font: .systemFont(ofSize: 10.5),
                color: primaryText, lineHeight: 14)
    currentY -= boundsOf(strings.coverIntroBody,
                         font: .systemFont(ofSize: 10.5),
                         width: contentWidth, lineHeight: 14) + 14
    // Table of contents
    drawString(strings.tocTitle,
               at: CGPoint(x: margin, y: currentY - 14),
               font: .systemFont(ofSize: 13, weight: .heavy),
               color: accentBlue)
    currentY -= 22
    for (i, title) in strings.tocEntries.enumerated() {
        let num = "\(i + 1)."
        drawString(num,
                   at: CGPoint(x: margin, y: currentY - 11),
                   font: .systemFont(ofSize: 10, weight: .heavy),
                   color: accentBlue)
        drawString(title,
                   at: CGPoint(x: margin + 20, y: currentY - 11),
                   font: .systemFont(ofSize: 10),
                   color: primaryText, maxWidth: contentWidth - 20)
        currentY -= 14
    }
    endCurrentPage()
}

func drawSectionDivider(section: ManualSection,
                        strings: LangStrings, lang: Lang) {
    startNewPage(footerLabel: strings.footerLabel, langCode: lang.rawValue)
    // Centered chip + section title
    currentY = pageRect.height * 0.62
    let chip = "\(strings.sectionWord) \(section.number)"
    let chipFont = NSFont.systemFont(ofSize: 11, weight: .heavy)
    let chipSize = (chip as NSString).size(withAttributes: [.font: chipFont])
    let chipPad: CGFloat = 14, chipH: CGFloat = 26
    let chipW = chipSize.width + chipPad * 2
    let cx = pageRect.width / 2
    let chipRect = CGRect(x: cx - chipW/2, y: currentY,
                          width: chipW, height: chipH)
    accentBlue.setFill()
    NSBezierPath(roundedRect: chipRect, xRadius: chipH/2, yRadius: chipH/2).fill()
    drawString(chip, at: CGPoint(x: chipRect.minX + chipPad,
                                 y: chipRect.midY - chipSize.height/2 + 1),
               font: chipFont, color: .white)
    // Title centered
    let titleFont = NSFont.systemFont(ofSize: 28, weight: .heavy)
    let titleH = boundsOf(section.title, font: titleFont,
                          width: contentWidth, lineHeight: 32)
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    style.minimumLineHeight = 32
    style.maximumLineHeight = 32
    let attrs: [NSAttributedString.Key: Any] = [
        .font: titleFont, .foregroundColor: primaryText, .paragraphStyle: style
    ]
    let titleRect = CGRect(x: margin, y: currentY - titleH - 24,
                           width: contentWidth, height: titleH + 4)
    (section.title as NSString).draw(in: titleRect, withAttributes: attrs)
    endCurrentPage()
}

func renderSection(_ section: ManualSection,
                   strings: LangStrings, lang: Lang) {
    drawSectionDivider(section: section, strings: strings, lang: lang)
    startNewPage(footerLabel: strings.footerLabel, langCode: lang.rawValue)
    // Section header on first content page
    let chip = "\(strings.sectionWord) \(section.number)"
    let chipFont = NSFont.systemFont(ofSize: 9.5, weight: .heavy)
    let chipSize = (chip as NSString).size(withAttributes: [.font: chipFont])
    let chipPad: CGFloat = 8, chipH: CGFloat = 18
    let chipW = chipSize.width + chipPad * 2
    let chipRect = CGRect(x: margin, y: currentY - chipH,
                          width: chipW, height: chipH)
    accentBlue.withAlphaComponent(0.15).setFill()
    NSBezierPath(roundedRect: chipRect, xRadius: chipH/2, yRadius: chipH/2).fill()
    drawString(chip, at: CGPoint(x: chipRect.minX + chipPad,
                                 y: chipRect.midY - chipSize.height/2),
               font: chipFont, color: accentBlue)
    currentY -= chipH + 8
    drawString(section.title,
               at: CGPoint(x: margin, y: currentY - 22),
               font: .systemFont(ofSize: 20, weight: .heavy),
               color: primaryText,
               maxWidth: contentWidth)
    currentY -= 32
    for e in section.elements { render(e) }
    endCurrentPage()
}

// MARK: - Content type

struct LangStrings {
    let subtitle: String
    let welcome: String
    let coverIntroTitle: String
    let coverIntroBody: String
    let tocTitle: String
    let tocEntries: [String]
    let sectionWord: String
    let footerLabel: String
    let sections: [ManualSection]
}


// MARK: - Content : FRANÇAIS

let strFR = LangStrings(
    subtitle: "Manuel utilisateur — Contrôle qualité PAD broadcast & OTT",
    welcome: "Bienvenue 🎬 — vous tenez en main le manuel complet de MisiQC Pro, l'outil de contrôle qualité automatique des fichiers PAD pour la diffusion linéaire (TV) et les plateformes OTT.",
    coverIntroTitle: "À propos de ce manuel",
    coverIntroBody: "Ce manuel décrit pas à pas l'installation, l'activation de la licence, l'interface, les 72 profils chaînes et plateformes pris en charge, les variantes audio, le pipeline d'analyse complet, la lecture du rapport QC, les exports (PDF, CSV, guide de correction) et tous les réglages avancés. Conservez-le à portée de main : il sert de référence pour décoder chaque résultat affiché par l'application.",
    tocTitle: "Sommaire",
    tocEntries: [
        "Présentation, installation & activation",
        "Tour de l'interface",
        "Profils chaînes & variantes audio",
        "Lancer une analyse",
        "Comprendre le rapport QC",
        "Réglages & paramètres avancés",
        "Exports : PDF, guide de correction, CSV",
        "Licence, mises à jour & support",
    ],
    sectionWord: "Section",
    footerLabel: "Manuel utilisateur",
    sections: [
        ManualSection(number: 1,
                      title: "Présentation, installation & activation",
                      elements: [
            .h2("Qu'est-ce que MisiQC Pro ?"),
            .p("MisiQC Pro est un logiciel macOS natif, non sandboxé, conçu pour le contrôle qualité automatique des fichiers PAD (Prêt À Diffuser) destinés aux chaînes de télévision linéaires (France TV, ARTE, TF1, M6, BBC, Canal+, etc.) et aux plateformes OTT (Netflix, Amazon Prime Video, Disney+, Apple TV+, etc.)."),
            .p("Il extrait les métadonnées techniques du fichier (conteneur, codec, résolution, framerate, GOP, mapping audio, timecode…), mesure la conformité audio EBU R128 (LUFS intégrée, True Peak, LRA), détecte les défauts de contenu (noirs, silences, dead pixels, frames dupliquées, frames figées, événements photosensibles), puis compare chaque mesure au cahier des charges officiel du diffuseur sélectionné. Le verdict est rendu en moins d'une minute pour la plupart des programmes."),
            .card(title: "Pourquoi un manuel ?",
                  body: "Le rapport généré par MisiQC Pro est dense : 30+ contrôles, mesures EBU R128, séries temporelles. Ce manuel donne le sens exact de chaque ligne, le rationnel des seuils, et les recommandations de correction lorsqu'un contrôle échoue.",
                  accent: accentBlue),
            .h2("Configuration requise"),
            .keyValueTable([
                ("Système",        "macOS 14 (Sonoma) ou ultérieur · Apple Silicon ou Intel"),
                ("Espace disque",  "~150 Mo pour l'application · espace libre proportionnel aux fichiers analysés"),
                ("Mémoire vive",   "8 Go minimum recommandés"),
                ("Réseau",         "Connexion internet requise uniquement pour les mises à jour Sparkle et l'activation initiale"),
                ("Permissions",    "Accès en lecture aux fichiers analysés (l'app n'écrit jamais sur les sources)"),
            ]),
            .h2("Installation"),
            .numbered([
                "Rendez-vous sur la page officielle de téléchargement : https://github.com/misilab/misiqcpro/releases/latest",
                "Téléchargez le fichier MisiQC-Pro-X.Y.Z.dmg (~65 Mo). L'archive est signée par mon Apple Developer ID et notarisée par Apple — aucune alerte Gatekeeper bloquante au premier lancement.",
                "Double-cliquez sur le DMG. Une fenêtre s'ouvre avec MisiQC Pro à gauche et un raccourci Applications à droite.",
                "Glissez MisiQC Pro dans le raccourci Applications. L'installation est terminée.",
                "Lancez l'application depuis Launchpad ou le Finder → dossier Applications.",
            ]),
            .card(title: "Période d'essai",
                  body: "Au premier lancement, MisiQC Pro démarre une période d'essai gratuite de 7 jours. Toutes les fonctions sont disponibles, y compris les exports PDF, CSV et guide de correction. Au-delà des 7 jours, l'application reste utilisable pour visualiser les rapports mais les exports sont désactivés jusqu'à l'activation d'une licence.",
                  accent: accentMint),
            .h2("Activation de votre licence"),
            .p("Après votre achat sur Payhip, vous recevez par email une clé de 47 caractères au format : XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX (8 groupes de 5, séparés par des tirets)."),
            .numbered([
                "Ouvrez MisiQC Pro.",
                "Menu MisiQC Pro → Réglages… (raccourci ⌘ ,).",
                "Cliquez sur l'onglet 🔑 Licence.",
                "Copiez la clé entière depuis votre email (⌘C).",
                "Collez-la (⌘V) dans le champ « Clé reçue par email ». Le compteur sous le champ doit afficher 40 / 40 en vert.",
                "Cliquez sur Activer. Le message « Merci ! Licence à vie active. » confirme la réussite.",
            ]),
            .card(title: "En cas d'erreur",
                  body: "« Clé incomplète (X/40 caractères) » → votre copier-coller est partiel ; sélectionnez la clé en entier depuis l'email puis recopiez.\n« Signature invalide » → la clé a été altérée (caractère manquant ou ajout par erreur). Demandez une nouvelle clé à contact@misiraca.com.\n« Format de clé non reconnu » → votre version de MisiQC Pro est trop ancienne ; mettez à jour via le menu MisiQC Pro → Vérifier les mises à jour…",
                  accent: accentPeach),
            .h2("Multi-Mac et stockage de la clé"),
            .bullets([
                "Votre clé est valable sur tous vos Macs personnels — aucune limitation matérielle.",
                "La clé est stockée chiffrée dans votre Trousseau macOS (kSecAttrAccessibleAfterFirstUnlock).",
                "Vous pouvez désactiver la licence à tout moment depuis l'onglet Licence → bouton « Désactiver la licence ». Cela permet par exemple de transférer la clé sur un autre Mac ou de revenir en mode essai.",
                "Aucune connexion serveur n'est nécessaire pour valider la clé : la vérification est faite en local par HMAC-SHA256 contre un secret embarqué dans l'application.",
            ]),
        ]),
        ManualSection(number: 2,
                      title: "Tour de l'interface",
                      elements: [
            .h2("Disposition générale"),
            .p("La fenêtre principale de MisiQC Pro adopte une disposition à deux colonnes, optimisée pour les grands écrans (taille idéale 1500 × 1020 px, redimensionnable). À gauche se trouve la barre latérale de sélection de profil chaîne, à droite la zone de travail où vous déposez le fichier, choisissez la variante audio et consultez le rapport."),
            .h2("Barre latérale (gauche)"),
            .bullets([
                "Liste des 72 profils chaînes / plateformes, regroupés logiquement : TV France, TV Europe, TV International, OTT, Réseaux sociaux.",
                "Chaque profil affiche un badge de confiance : Vérifié (spec officielle référencée), Standard (consolidé public), Générique (template OTT typique).",
                "Recherche intégrée en haut de la liste pour filtrer par nom.",
                "Bouton « Voir les specs » sur le profil actif : ouvre une fenêtre modale détaillée avec l'intégralité du cahier des charges.",
                "Légende des badges en bas de liste.",
            ]),
            .h2("En-tête"),
            .p("L'en-tête affiche le logo MisiQC Pro, le nom de l'application, la version du cahier des charges chargé (ex. « Annexe CDE 2023-01 ») et un pavé de statut de licence (essai en cours, licence active, expirée). En période d'essai, une bande colorée apparaît en haut de la fenêtre avec le nombre de jours restants et un bouton « Acheter une licence » qui ouvre Payhip dans votre navigateur."),
            .h2("Zone de dépôt et sélecteurs"),
            .bullets([
                "Zone de drop : glissez-déposez un fichier vidéo (MXF, MOV, MP4, M2V, …) ou cliquez pour choisir via le sélecteur natif macOS.",
                "Sélecteur de variante audio : pastilles VF / VF+VO / VF+AD / VF+VO+AD. Seules les variantes prévues par le profil sélectionné sont activables.",
                "Pavé Tolérance : rappel du niveau de tolérance signal actif (Pro broadcast / Premium broadcast / EBU R103 / Permissif OTT) avec brève explication.",
                "Stats strip : compteurs en temps réel (durée, taille, fps détecté) lorsque le fichier est chargé.",
            ]),
            .h2("Panneau résultats"),
            .p("Tant qu'aucune analyse n'est lancée, le panneau central affiche un état vide invitant à déposer un fichier. Pendant l'analyse, une grille des 16 étapes du pipeline s'anime — vous voyez en temps réel quelle phase est en cours (probing → GOP → interlace → crop → loudness → phase → audio stats → black detect → silence detect → signal range → freeze detect → duplicate detect → dead pixel → PSE detect → leader → audio pops → metadata extras → finalisation). Une fois l'analyse terminée, la liste des contrôles s'affiche avec un pictogramme par statut : ✓ vert (Pass), ⚠ jaune (Warning), ✗ rouge (Fail)."),
            .h2("Barre inférieure"),
            .bullets([
                "Effacer : remet l'interface à zéro pour analyser un autre fichier.",
                "Exporter PDF : enregistre le rapport complet en PDF A4.",
                "Exporter CSV : enregistre les résultats au format CSV (deux blocs : métadonnées + table des contrôles + éventuellement série temporelle signalstats).",
                "Exporter guide de correction : génère un PDF n'incluant que les contrôles en échec, avec recettes ffmpeg, DaVinci Resolve, Premiere Pro et Avid Media Composer.",
                "Révéler le fichier : ouvre le Finder sur le fichier analysé.",
            ]),
            .h2("Menus & raccourcis clavier"),
            .keyValueTable([
                ("Ouvrir un fichier",          "⌘ O"),
                ("Lancer l'analyse",           "⌘ ⏎"),
                ("Exporter PDF",               "⌘ E"),
                ("Exporter CSV",               "⇧ ⌘ E"),
                ("Réinitialiser l'analyse",    "⇧ ⌘ R"),
                ("Révéler le fichier",         "⌘ R"),
                ("Réglages",                   "⌘ ,"),
                ("Profil 1 à 9",               "⌘ 1 à ⌘ 9"),
                ("Variante audio 1 à 4",       "⌥ ⌘ 1 à ⌥ ⌘ 4"),
                ("Vérifier les mises à jour",  "Menu MisiQC Pro"),
            ]),
        ]),
        ManualSection(number: 3,
                      title: "Profils chaînes & variantes audio",
                      elements: [
            .h2("Le concept de profil chaîne"),
            .p("Un profil chaîne est une description structurée du cahier des charges technique d'un diffuseur : quel conteneur (MXF OP1a, MOV, MP4, IMF), quel codec vidéo (MPEG-2 422P@HL, AVC-Intra 100, ProRes 422 HQ, AVC, HEVC), quelle résolution et framerate, quel mapping audio (nombre de pistes, langues), quelle cible de loudness EBU R128, quel timecode de début, quelles amorces, etc."),
            .p("MisiQC Pro est fourni avec 72 profils prêts à l'emploi, mis à jour à chaque version du logiciel à partir des cahiers des charges publics ou consolidés des diffuseurs."),
            .h2("Badges de confiance"),
            .bullets([
                "Vérifié — La spécification correspond à un document officiel référencé (annexe CDE FranceTV 2023, BBC DPP 2017, etc.).",
                "Standard — Spécification consolidée à partir de sources publiques et de retours d'expérience post-producteurs ; suffisante pour 99 % des livraisons.",
                "Générique — Template OTT typique (1080p HEVC ou ProRes 422 HQ) à utiliser quand le diffuseur n'a pas publié de spec précise.",
            ]),
            .h2("Liste des profils pris en charge"),
            .columnedList(headline: "TV linéaire — France",
                          items: [
                              "France Télévisions", "TF1", "M6", "Canal+ (via OTT)", "ARTE",
                              "C8", "W9", "TMC", "TFX", "BFMTV", "CNews", "LCI",
                              "France 24", "Gulli", "Paris Première", "6ter", "TV5MONDE",
                          ], columns: 3),
            .columnedList(headline: "TV linéaire — Europe",
                          items: [
                              "BBC (UK)", "ITV (UK)", "Channel 4 (UK)", "Sky UK",
                              "ARD/ZDF (DE)", "ProSieben (DE)", "RTL (DE)", "Deutsche Welle",
                              "ORF (AT)", "SRG SSR (CH)", "NPO (NL)", "RTBF (BE)", "VRT (BE)",
                              "RAI (IT)", "Mediaset (IT)", "TVE (ES)",
                              "RTP (PT)", "TVP (PL)",
                              "DR (DK)", "SVT (SE)", "NRK (NO)", "YLE (FI)",
                              "EuroNews",
                          ], columns: 3),
            .columnedList(headline: "TV linéaire — International",
                          items: [
                              "ABC (US)", "NBC (US)", "CBS (US)", "FOX (US)", "PBS (US)",
                              "CBC (CA)", "TVA (CA)",
                              "Al Jazeera",
                          ], columns: 3),
            .columnedList(headline: "OTT / Streaming",
                          items: [
                              "Netflix", "Amazon Prime Video", "Apple TV+", "Disney+",
                              "HBO Max", "Hulu", "Peacock", "Paramount+", "Pluto TV",
                              "BritBox", "Crunchyroll", "MUBI", "Tubi",
                              "DAZN", "Eurosport",
                          ], columns: 3),
            .columnedList(headline: "Réseaux sociaux & vidéo en ligne",
                          items: [
                              "YouTube", "TikTok", "Instagram", "Facebook",
                              "LinkedIn", "Vimeo", "Twitch",
                          ], columns: 3),
            .columnedList(headline: "Specs de référence multi-broadcast",
                          items: [
                              "DPP (Digital Production Partnership UK)",
                          ], columns: 3),
            .h2("Les 4 variantes audio"),
            .p("Une livraison PAD peut contenir plusieurs versions linguistiques sur des pistes audio différentes. MisiQC Pro reconnaît 4 variantes typiques. Chaque profil chaîne déclare lesquelles sont autorisées."),
            .keyValueTable([
                ("VF",          "Version Française seule. Une paire stéréo (2 pistes mono : L+R). C'est la livraison minimum pour la France et la Belgique francophone."),
                ("VF + VO",     "Version Française + Version Originale (généralement anglais). Quatre pistes mono : VF L, VF R, VO L, VO R. Demandé par FranceTV pour les fictions étrangères."),
                ("VF + AD",     "Version Française + Audio Description (voix-off décrivant l'action pour les déficients visuels). Quatre pistes mono : VF L, VF R, AD L, AD R. Obligatoire sur certaines tranches horaires en France."),
                ("VF + VO + AD","Cumul des trois. Six pistes mono : VF L, VF R, VO L, VO R, AD L, AD R. C'est le cas le plus complet, demandé par exemple par ARTE pour les fictions internationales."),
            ]),
            .card(title: "Variante par défaut",
                  body: "Si aucune variante n'est explicitement sélectionnée, MisiQC Pro applique la variante par défaut (VF) ou la première variante autorisée par le profil. Vous pouvez changer la variante par défaut dans Réglages → Général → Variante par défaut.",
                  accent: accentBlue),
        ]),
        ManualSection(number: 4,
                      title: "Lancer une analyse",
                      elements: [
            .h2("Formats de fichiers pris en charge"),
            .p("MisiQC Pro accepte tous les formats lisibles par ffmpeg / ffprobe (intégrés dans l'application). Les plus fréquents en broadcast sont :"),
            .bullets([
                ".mxf — MXF OP1a (XDCAM HD422, AVC-Intra, AS-10, RDD9). Format de référence pour la diffusion linéaire France et UK.",
                ".mov — QuickTime (ProRes 422, ProRes 422 HQ, ProRes 4444, AVC). Largement utilisé pour les livraisons OTT premium.",
                ".mp4 — MP4 / ISO BMFF (AVC, HEVC, AAC). Format prédominant pour les plateformes OTT mainstream et les réseaux sociaux.",
                ".m2v / .ts — flux MPEG-2 transport / élémentaire (rares aujourd'hui, mais supportés).",
                "Autres conteneurs reconnus : .mkv, .imf (Interoperable Master Format), .avi.",
            ]),
            .h2("Lancer l'analyse, étape par étape"),
            .numbered([
                "Sélectionnez le profil chaîne dans la barre latérale (ou raccourci ⌘ 1 à ⌘ 9).",
                "Glissez-déposez le fichier vidéo dans la zone de drop centrale (ou ⌘ O pour le sélecteur Finder).",
                "Choisissez la variante audio si le profil en propose plusieurs (⌥ ⌘ 1 à ⌥ ⌘ 4).",
                "Cliquez sur le bouton « Lancer » ou ⌘ ⏎. L'analyse démarre.",
                "Attendez la fin du pipeline — la durée est proportionnelle à celle du programme (~30 sec pour 5 min, ~5 min pour 1 h).",
            ]),
            .h2("Les 16 étapes du pipeline"),
            .p("Pendant l'analyse, vous voyez progresser les 16 phases ci-dessous. Chaque phase utilise ffprobe ou ffmpeg en sous-processus, avec drainage non-bloquant de stdout/stderr pour ne jamais figer l'interface."),
            .keyValueTable([
                ("1. Probing",         "ffprobe extrait toutes les métadonnées (streams, format, chapitres) en JSON."),
                ("2. GOP",             "Analyse de la structure GOP sur les 300 premières frames (taille, ouverture/fermeture, motif IBP)."),
                ("3. Interlace",       "Filtre idet sur 600 frames pour détecter trame supérieure/inférieure ou progressif."),
                ("4. Crop",            "cropdetect repère les éventuels bandeaux noirs (letterbox / pillarbox)."),
                ("5. Loudness",        "ebur128 mesure LUFS intégrée + True Peak + LRA pour chaque paire stéréo déclarée."),
                ("6. Phase",           "Corrélation L/R par paire stéréo (détection d'inversion de phase ou de mono accidentel)."),
                ("7. Audio Stats",     "DC offset, peak, RMS par piste audio. Détecte clipping, offset DC, ambiances trop basses."),
                ("8. Black Detect",    "blackdetect repère les plages noires continues plus longues que le seuil configuré."),
                ("9. Silence Detect",  "silencedetect repère les silences plus longs que le seuil configuré, sur chaque piste."),
                ("10. Signal Range",   "signalstats échantillonne luminance et chrominance pour détecter infra-black, super-white et excursions Y."),
                ("11. Freeze Detect",  "Détection de séquences gelées (image strictement identique pendant ≥2 secondes)."),
                ("12. Duplicate",      "mpdecimate mesure le ratio de frames dupliquées (révèle un mauvais reconform 25i/50i ou un freeze partiel)."),
                ("13. Dead Pixels",    "Échantillonnage de 12 frames espacées avec stride 8 px pour repérer des pixels morts ou bloqués."),
                ("14. PSE",            "Photosensitive Epilepsy : détecte les flashs rapides (>3/seconde) potentiellement dangereux."),
                ("15. Leader",         "Recherche d'amorces SMPTE/EBU (color bars + tonalité 1 kHz) dans les 30 premières secondes."),
                ("16. Métadonnées",    "Vérifications complémentaires : sous-titres, métadonnées HDR (Mastering Display, MaxCLL), AFD, post-roll."),
            ]),
            .card(title: "Annuler une analyse",
                  body: "Vous pouvez arrêter l'analyse en cours via le bouton « Annuler » qui apparaît pendant le pipeline. Les sous-processus ffmpeg/ffprobe sont alors terminés proprement avec SIGTERM.",
                  accent: accentPeach),
        ]),
        ManualSection(number: 5,
                      title: "Comprendre le rapport QC",
                      elements: [
            .h2("Verdict global"),
            .p("Le rapport s'ouvre sur un verdict global : Pass (✓ vert), Warning (⚠ orange) ou Fail (✗ rouge). Le verdict global correspond au pire statut parmi tous les contrôles : un seul Fail suffit à faire passer le verdict global à Fail. Sont également affichés les compteurs : N contrôles passés, M avertissements, K échecs."),
            .h2("Les trois statuts"),
            .keyValueTable([
                ("Pass (✓)",     "Le contrôle satisfait la spécification du diffuseur dans les tolérances. Aucune action requise."),
                ("Warning (⚠)",  "Le contrôle est dans une zone d'alerte : la spécification est techniquement respectée mais à la limite du tolérable. À surveiller, surtout si plusieurs warnings se cumulent."),
                ("Fail (✗)",     "La spécification n'est pas respectée. Le fichier sera très probablement rejeté par le diffuseur. Corrigez avant de livrer."),
            ]),
            .h2("Catégorie : Conteneur"),
            .bullets([
                "Format du conteneur (MXF, MOV, MP4, IMF…) — doit correspondre exactement à la spec.",
                "Pattern opérationnel (OP1a pour MXF — un seul fichier auto-contenu vs OP-Atom qui sépare vidéo et audio).",
                "Shim broadcast (AS-10 HIGH_HD_2014 pour TF1/M6, RDD9 pour FranceTV, IMF pour OTT premium…).",
            ]),
            .h2("Catégorie : Vidéo"),
            .bullets([
                "Codec — MPEG-2 422P@HL (XDCAM HD422), AVC-Intra 100, ProRes 422 HQ, AVC, HEVC… La valeur attendue est strictement définie par profil.",
                "Profil/level — précise la conformité fine du codec (ex. AVC High@L4.0).",
                "Résolution — 1920×1080 pour HD broadcast, 3840×2160 pour UHD-1.",
                "Framerate — modélisé comme un rationnel num/den (25/1, 30000/1001 pour 29.97, 24000/1001 pour 23.976) pour éviter les faux négatifs liés aux décimaux.",
                "Mode balayage — interlacé (i) ou progressif (p). En broadcast français : généralement 25i (50 trames/s, trame supérieure d'abord).",
                "Bitrate vidéo — 50 Mb/s CBR pour la plupart des diffuseurs HD broadcast français, plus variable pour l'OTT.",
                "Espace colorimétrique — BT.709 pour HD broadcast, BT.2020/PQ ou HLG pour HDR.",
                "Range colorimétrique — « TV / limited » (16-235 sur 8 bits) ou « PC / full » (0-255). Le mauvais range est l'une des erreurs les plus fréquentes en broadcast.",
                "GOP — taille (généralement 12 frames pour le broadcast français), fermé/ouvert, structure (IBBP, IBP).",
            ]),
            .h2("Catégorie : Audio"),
            .bullets([
                "Codec audio — PCM 24-bit 48 kHz pour la quasi-totalité des livraisons broadcast, AAC pour l'OTT.",
                "Nombre de pistes — doit correspondre à la variante choisie (2 pour VF, 4 pour VF+VO ou VF+AD, 6 pour VF+VO+AD).",
                "Mapping des pistes — par exemple, piste 1 = VF L, piste 2 = VF R, piste 3 = VO L, piste 4 = VO R. Un mauvais mapping inverse la stéréo ou met la VO sur le canal de la VF.",
                "DC offset — un offset >1 % indique un problème de chaîne audio en amont. L'app le signale en warning.",
                "Phase L/R — corrélation entre les deux canaux d'une paire stéréo. Une corrélation négative signale une inversion de phase (souvent un fil rouge/blanc inversé en captation).",
                "Audio pops — clics audio supérieurs au seuil défini par la spec.",
            ]),
            .h2("Catégorie : Loudness EBU R128"),
            .p("La mesure EBU R128 est faite par paire stéréo (via le filtre amerge ffmpeg) pour chacune des paires déclarées par le mapping audio. Trois grandeurs sont rendues :"),
            .bullets([
                "LUFS intégrée — niveau de loudness moyen sur toute la durée du programme. Cible broadcast : -23 LUFS ± 1 LU pour la France et l'Europe, -24 LUFS aux US (ATSC A/85), -16 LUFS pour le streaming musical.",
                "True Peak (dBTP) — crête vraie inter-échantillon. Plafond broadcast : -3 dBTP. Au-dessus, risque de saturation après transcodage.",
                "LRA (Loudness Range) — différence en LU entre le 10ᵉ et le 95ᵉ percentile de la courbe de loudness. Mesure la dynamique macroscopique. Plafond France TV : 20 LU (avec tolérance +5).",
            ]),
            .card(title: "Lecture du résultat loudness",
                  body: "Pour chaque paire stéréo, le rapport affiche la valeur mesurée et la cible (avec sa tolérance). Si la LUFS intégrée est à -23.4 LUFS avec une cible -23 ± 1, le contrôle passe. À -21.9 LUFS, il devient Fail. La même logique s'applique au True Peak et au LRA.",
                  accent: accentMint),
            .h2("Catégorie : Structure"),
            .bullets([
                "Timecode de début — 00:00:00:00 pour FranceTV/ARTE, 10:00:00:00 pour Canal+, 01:00:00:00 pour M6/TF1. La modélisation du TC inclut le drop-frame quand applicable (Amérique du Nord en 29.97).",
                "Durée du fichier — vérifiée contre la durée déclarée dans les métadonnées du conteneur (cohérence).",
                "Amorces — recherche de barres de couleur SMPTE/EBU et d'une tonalité 1 kHz dans les 30 premières secondes. Demandé par certaines chaînes.",
                "Sous-titres — présence d'une piste de sous-titres CEA-608/708 ou de sous-titres embarqués (selon spec).",
                "AFD (Active Format Description) — drapeau décrivant le format actif (4:3, 16:9, lettre-boxé, etc.).",
                "Métadonnées HDR — Mastering Display Primaries + Max Content Light Level (MaxCLL) + Max Frame Average Light Level (MaxFALL) pour les livraisons HDR10.",
                "Post-roll — noir final, généralement 5 secondes après l'image. Vérifié pour s'assurer que le programme ne se termine pas brutalement sur une frame de contenu.",
            ]),
            .h2("Défauts de contenu"),
            .bullets([
                "Noirs — segments noirs continus plus longs que le seuil (par défaut 1 seconde). Un noir long en plein milieu d'un programme est suspect.",
                "Silences — segments silencieux plus longs que le seuil (par défaut 1 seconde) sur chaque piste audio. Permet de repérer une piste manquante (totalement silencieuse) ou des trous audio.",
                "Frames figées (freeze) — séquences strictement identiques pendant ≥ 2 secondes. Révèle une perte de signal en capture ou un bug d'encodage.",
                "Frames dupliquées — ratio de frames identiques mesuré par mpdecimate. Un ratio > 5 % révèle un mauvais reconform (par exemple du 24p vers du 25i sans pulldown).",
                "Dead pixels — pixels morts ou bloqués détectés par sampling sur 12 frames. Rare aujourd'hui en environnement broadcast.",
                "PSE (Photosensitive Epilepsy) — détection des flashs rapides (>3 flashs/seconde) qui peuvent déclencher des crises chez les personnes photosensibles. Recommandation OFCOM/CSA stricte.",
            ]),
        ]),
        ManualSection(number: 6,
                      title: "Réglages & paramètres avancés",
                      elements: [
            .h2("Ouvrir les Réglages"),
            .p("Menu MisiQC Pro → Réglages… ou raccourci ⌘ , — la fenêtre Réglages s'ouvre en mode flottant (640 × 520 px) avec quatre onglets : Général, Détection, Licence, À propos."),
            .h2("Onglet Général"),
            .keyValueTable([
                ("Langue de l'interface",       "Français / English / Español. Le changement est appliqué instantanément (menus, rapports, exports PDF/CSV)."),
                ("Profil chaîne par défaut",    "Profil pré-sélectionné au lancement de l'application. Pratique si vous travaillez en permanence pour la même chaîne."),
                ("Variante audio par défaut",   "Pré-sélectionnée quand un nouveau fichier est chargé. Choisir VF si vous livrez majoritairement des programmes monolingues."),
                ("Réinitialiser les préférences","Bouton destructif (rouge) qui remet toutes les préférences à leur valeur d'usine. Confirmé par une popup."),
            ]),
            .h2("Onglet Détection"),
            .bullets([
                "Seuil de détection des noirs — durée minimale (0.2 à 10 s, par défaut 1.0 s) pour qu'un segment noir soit signalé. Réduisez à 0.5 s si vous chassez des coupures abruptes.",
                "Seuil de détection des silences — durée minimale (0.2 à 30 s, par défaut 1.0 s). Augmentez à 3 s ou 5 s sur des programmes longs avec respirations naturelles.",
                "Niveau de tolérance signal range — règle l'agressivité des contrôles d'excursion luma/chroma (super-white, infra-black). Quatre presets disponibles, détaillés ci-dessous.",
            ]),
            .h2("Les 4 niveaux de tolérance signal range"),
            .keyValueTable([
                ("Pro broadcast (strict)",
                 "Tolérance zéro pour les excursions luma. Visez ce niveau pour France TV, ARTE, BBC : Pass si <0.1% de pixels hors range, Warning si <0.5%."),
                ("Premium broadcast (recommandé)",
                 "Tolérance codec : un léger débordement est admis. Pass si <0.5%, Warning si <1%. C'est le réglage par défaut, valable pour la majorité des livraisons."),
                ("EBU R103 v3.0 (norme officielle)",
                 "Applique strictement les seuils de la norme EBU R103 v3.0 : Pass si <1%, Warning si <2%. Utile pour valider une livraison contre le standard sans interprétation."),
                ("Permissif OTT (Netflix, Amazon…)",
                 "Très souple. Pass si <5%, Warning si <1%. Convient aux livraisons OTT qui transcodent ensuite vers de multiples cibles."),
            ]),
            .h2("Onglet Licence"),
            .p("Statut de licence en haut (essai / licence à vie / expirée), champ de saisie de clé en monospace, compteur 40/40, boutons Activer, Acheter une licence (ouvre Payhip) et Désactiver la licence (visible uniquement quand une licence est active)."),
            .h2("Onglet À propos"),
            .p("Logo MisiQC Pro, nom de l'application, courte description de la valeur ajoutée, lien vers www.misiraca.com, version du logiciel."),
        ]),
        ManualSection(number: 7,
                      title: "Exports : PDF, guide de correction, CSV",
                      elements: [
            .h2("Export PDF du rapport"),
            .p("Le PDF du rapport est conçu pour être archivé, transmis au diffuseur ou joint à un email de livraison. Format A4 portrait, généré par le rendu natif PDFKit."),
            .bullets([
                "Page de couverture : nom du fichier, profil chaîne (avec version de la spec), date d'analyse, verdict global avec compteurs Pass/Warning/Fail.",
                "Métadonnées du fichier : durée, taille, framerate détecté, codec, etc.",
                "Tableau par catégorie : Conteneur, Vidéo, Audio, Loudness, Structure, Contenu, avec libellé / valeur attendue / valeur mesurée / statut.",
                "Page paysage optionnelle : timeline signal range (courbe sur la durée du programme) si la série temporelle a été échantillonnée.",
                "Pied de page : version de l'app, version du profil, watermark de traçabilité.",
            ]),
            .h2("Filigrane (watermark)"),
            .keyValueTable([
                ("Période d'essai",     "« RAPPORT GÉNÉRÉ EN VERSION ESSAI » en pied de page (gris discret)."),
                ("Licence active",      "« Licence: XXXXX · Hôte: Nom-du-Mac » — 5 premiers caractères de la clé + nom de la machine. Permet de tracer un partage non autorisé."),
                ("Essai expiré",        "Le PDF n'est pas exportable tant que l'essai est expiré et qu'aucune licence n'est activée."),
            ]),
            .h2("Guide de correction (Remediation Guide)"),
            .p("Le guide de correction est un PDF complémentaire généré sur demande. Il ne contient que les contrôles en échec (statut Fail) avec, pour chacun, des recettes de correction concrètes."),
            .bullets([
                "Page de couverture : récap du fichier source, nombre de problèmes à corriger, avertissement de responsabilité.",
                "Une fiche par échec : libellé du contrôle, cause technique, recettes de correction logiciel par logiciel.",
                "Recettes ffmpeg (ligne de commande exacte à exécuter en terminal).",
                "Recettes DaVinci Resolve (menu Color Science, Project Settings, Deliver tab).",
                "Recettes Adobe Premiere Pro (panneaux Effects, Lumetri Color, Audio Mixer, Export Media).",
                "Recettes Avid Media Composer (modules d'export, settings PCM, Source Settings).",
                "Liens vers la doc officielle du diffuseur et du logiciel quand pertinent.",
            ]),
            .card(title: "Quand utiliser le guide de correction ?",
                  body: "Quand votre rapport principal contient un ou plusieurs échecs, exportez le guide de correction et transmettez-le à l'étalonneur / mixeur / monteur. Il pourra appliquer la recette pour le logiciel qu'il utilise sans avoir à interpréter le cahier des charges du diffuseur.",
                  accent: accentBlue),
            .h2("Export CSV"),
            .p("Le CSV est destiné aux exploitations en tableur (Excel, Numbers, Google Sheets) ou en script (pandas, R). Trois blocs :"),
            .bullets([
                "Bloc 1 — Métadonnées : Fichier, Profil, Date d'analyse, Verdict, compteurs Pass/Warning/Fail.",
                "Bloc 2 — Table des contrôles : colonnes Catégorie, Libellé, Attendu, Mesuré, Statut, Détail.",
                "Bloc 3 (optionnel) — Série temporelle signalstats échantillonnée toutes les N frames : pts_sec, YAVG, YMIN, YMAX, BRNG, TOUT, VREP. Importable directement dans pandas pour tracer la timeline.",
            ]),
        ]),
        ManualSection(number: 8,
                      title: "Licence, mises à jour & support",
                      elements: [
            .h2("Licence à vie"),
            .bullets([
                "Une seule clé suffit, valable à vie, sur tous vos Macs personnels.",
                "Aucune limitation matérielle, aucun appel serveur pour la validation : 100% offline.",
                "Les mises à jour majeures sont incluses dans la licence à vie.",
                "Vous pouvez transférer votre licence en désactivant sur un Mac (Réglages → Licence → Désactiver) puis en réactivant sur un autre.",
            ]),
            .h2("Mises à jour automatiques (Sparkle)"),
            .bullets([
                "MisiQC Pro intègre Sparkle 2.x, le framework de mise à jour standard pour les apps macOS hors Mac App Store.",
                "À chaque lancement, l'app vérifie en arrière-plan si une nouvelle version est disponible.",
                "Vous pouvez forcer la vérification via menu MisiQC Pro → Vérifier les mises à jour…",
                "Les mises à jour sont signées par une clé Ed25519 dédiée. Une mise à jour non signée par mon Mac est refusée par Sparkle — aucun risque de fausse mise à jour malveillante.",
                "La mise à jour est appliquée au redémarrage de l'app, sans perdre votre licence ni vos préférences.",
            ]),
            .h2("Support & contact"),
            .keyValueTable([
                ("Email",         "contact@misiraca.com — réponse sous 48 h en jours ouvrés."),
                ("Site",          "www.misiraca.com — actualités et notes de version."),
                ("Bugs",          "Précisez : version de l'app (Menu MisiQC Pro → À propos), version de macOS, description du problème, et idéalement un échantillon vidéo (≤ 30 s) qui reproduit le bug."),
                ("Demande feature","Bienvenues — précisez le contexte broadcast (chaîne, type de programme) pour aider à prioriser."),
            ]),
            .h2("Foire aux questions"),
            .card(title: "L'analyse est très lente sur un long programme — c'est normal ?",
                  body: "Oui, la durée d'analyse est proportionnelle à celle du programme. Sur un 1 h 30, comptez ~10 minutes. L'application fait passer la totalité du fichier dans plusieurs filtres ffmpeg (ebur128, signalstats, mpdecimate, etc.) — c'est inhérent à la profondeur des contrôles.",
                  accent: accentBlue),
            .card(title: "Mon fichier MXF passe en Fail sur le contrôle « shim » alors que les valeurs vidéo semblent bonnes.",
                  body: "Le shim (AS-10 HIGH_HD_2014, RDD9, etc.) est une étiquette portée par les métadonnées du conteneur MXF. Si votre encodeur ne renseigne pas ce shim explicitement, il sera marqué comme manquant même si tout le reste est conforme. Solution : ré-encoder avec une chaîne qui pose explicitement le shim, ou utiliser un re-wrapper MXF dédié.",
                  accent: accentPeach),
            .card(title: "Le contrôle loudness affiche -22.7 LUFS pour une cible -23 ± 1. Pourquoi est-ce un Pass et non un Warning ?",
                  body: "Parce que -22.7 LUFS est dans la fenêtre de tolérance (-24 à -22 LUFS). Le contrôle ne devient Warning qu'à partir de l'approche des bornes (par exemple -22.0 ou -23.95) et Fail au-delà. La zone Warning est définie par chaque profil chaîne.",
                  accent: accentBlue),
            .card(title: "Puis-je analyser un fichier directement depuis un disque réseau ?",
                  body: "Oui, à condition que macOS ait monté le partage (SMB, AFP, NFS). MisiQC Pro accède au fichier en lecture seule via les API Foundation standards. Si le réseau est lent, l'analyse sera proportionnellement plus longue.",
                  accent: accentBlue),
            .card(title: "Et si je perds ma clé ?",
                  body: "Pas de panique : votre achat Payhip est lié à votre email. Contactez contact@misiraca.com en précisant l'email de votre achat, je vous renvoie votre clé.",
                  accent: accentMint),
            .h2("Conditions de licence"),
            .bullets([
                "✅ Usage personnel et professionnel illimité sur vos Macs.",
                "✅ Génération de rapports PDF / CSV / guide de correction illimitée.",
                "✅ Mises à jour mineures et majeures incluses à vie.",
                "❌ Revente, partage ou distribution de la clé interdits.",
                "❌ Reverse-engineering, désassemblage ou contournement de la vérification de licence interdits.",
                "Le partage non autorisé d'une clé peut être tracé via les watermarks des rapports PDF générés.",
            ]),
            .h2("Crédits"),
            .p("MisiQC Pro est conçu et développé par Matthieu Misiraca à Paris. L'application repose sur ffmpeg et ffprobe (LGPL), Sparkle 2.x (BSD), et l'écosystème SwiftUI / CryptoKit d'Apple."),
            .spacer(8),
            .card(title: "Merci pour votre confiance",
                  body: "Et bons contrôles qualité ! N'hésitez pas à m'écrire pour toute question, suggestion ou retour de production.\n— Matthieu",
                  accent: accentViolet),
        ]),
    ]
)

// MARK: - Content : ENGLISH

let strEN = LangStrings(
    subtitle: "User manual — Broadcast & OTT PAD quality control",
    welcome: "Welcome 🎬 — you are holding the complete user manual for MisiQC Pro, the automated QC tool for broadcast TV and OTT delivery masters.",
    coverIntroTitle: "About this manual",
    coverIntroBody: "This manual walks you through installation, license activation, the user interface, all 72 supported channel and platform profiles, audio variants, the full analysis pipeline, the QC report breakdown, exports (PDF, CSV, remediation guide) and every advanced setting. Keep it handy: it is the reference for decoding any result MisiQC Pro shows you.",
    tocTitle: "Table of contents",
    tocEntries: [
        "Introduction, installation & activation",
        "Interface tour",
        "Channel profiles & audio variants",
        "Running an analysis",
        "Understanding the QC report",
        "Settings & advanced parameters",
        "Exports: PDF, remediation guide, CSV",
        "License, updates & support",
    ],
    sectionWord: "Section",
    footerLabel: "User manual",
    sections: [
        ManualSection(number: 1,
                      title: "Introduction, installation & activation",
                      elements: [
            .h2("What is MisiQC Pro?"),
            .p("MisiQC Pro is a native macOS application, non-sandboxed, designed for automated quality control of PAD (Prêt À Diffuser, French acronym for delivery masters) files for linear television (France TV, ARTE, TF1, M6, BBC, Canal+, etc.) and OTT platforms (Netflix, Amazon Prime Video, Disney+, Apple TV+, etc.)."),
            .p("It extracts the technical metadata of a file (container, codec, resolution, framerate, GOP, audio mapping, timecode…), measures EBU R128 audio loudness (integrated LUFS, true peak, LRA), detects content defects (black, silence, dead pixels, duplicate frames, frozen segments, photosensitive epilepsy events), then compares every measurement to the official spec of the selected broadcaster. The verdict is rendered in less than a minute for most programmes."),
            .card(title: "Why a manual?",
                  body: "The report MisiQC Pro generates is dense: 30+ checks, EBU R128 metering, time-series data. This manual gives you the exact meaning of each line, the rationale behind every threshold, and the recommended fixes when a check fails.",
                  accent: accentBlue),
            .h2("System requirements"),
            .keyValueTable([
                ("System",          "macOS 14 (Sonoma) or later · Apple Silicon or Intel"),
                ("Disk space",      "~150 MB for the app · free space proportional to the files you analyse"),
                ("Memory",          "8 GB RAM minimum recommended"),
                ("Network",         "Internet required only for Sparkle updates and initial activation"),
                ("Permissions",     "Read-only access to the analysed files (the app never writes to source media)"),
            ]),
            .h2("Installation"),
            .numbered([
                "Go to the official download page: https://github.com/misilab/misiqcpro/releases/latest",
                "Download the MisiQC-Pro-X.Y.Z.dmg file (~65 MB). The archive is signed with my Apple Developer ID and notarised by Apple — no Gatekeeper alert on first launch.",
                "Double-click the DMG. A window opens with MisiQC Pro on the left and an Applications shortcut on the right.",
                "Drag MisiQC Pro onto the Applications shortcut. Installation done.",
                "Launch the app from Launchpad or the Finder → Applications folder.",
            ]),
            .card(title: "Trial period",
                  body: "On first launch, MisiQC Pro starts a free 7-day trial. All features are available, including PDF, CSV and remediation guide exports. After the 7 days, the app stays usable to view reports but exports are disabled until a licence is activated.",
                  accent: accentMint),
            .h2("Activating your licence"),
            .p("After your Payhip purchase you receive by email a 47-character key in the form: XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX (8 groups of 5 separated by hyphens)."),
            .numbered([
                "Open MisiQC Pro.",
                "Menu MisiQC Pro → Settings… (shortcut ⌘ ,).",
                "Click the 🔑 License tab.",
                "Copy the entire key from your email (⌘C).",
                "Paste (⌘V) into the « License key (from email) » field. The counter under the field should read 40 / 40 in green.",
                "Click Activate. The message « Thanks! Lifetime license active. » confirms success.",
            ]),
            .card(title: "If activation fails",
                  body: "« Incomplete key (X/40 characters) » → the copy-paste is partial; reselect the whole key from the email and try again.\n« Invalid signature » → the key was altered (missing or extra character). Email contact@misiraca.com for a new key.\n« Unsupported key format » → your MisiQC Pro version is too old; update via menu MisiQC Pro → Check for Updates…",
                  accent: accentPeach),
            .h2("Multi-Mac and key storage"),
            .bullets([
                "Your key is valid on all your personal Macs — no hardware limitation.",
                "The key is stored encrypted in your macOS Keychain (kSecAttrAccessibleAfterFirstUnlock).",
                "You can deactivate the licence at any time from the License tab → « Deactivate license » button. Useful to transfer the key to another Mac or revert to trial mode.",
                "No server connection is required to validate the key: verification happens locally via HMAC-SHA256 against a secret embedded in the application.",
            ]),
        ]),
        ManualSection(number: 2,
                      title: "Interface tour",
                      elements: [
            .h2("General layout"),
            .p("The main window of MisiQC Pro uses a two-column layout, optimised for large displays (ideal size 1500 × 1020 px, resizable). The left side hosts the channel-profile sidebar; the right side is the work area where you drop the file, pick the audio variant and review the report."),
            .h2("Sidebar (left)"),
            .bullets([
                "List of the 72 channel / platform profiles, logically grouped: France TV, Europe TV, International TV, OTT, Social media.",
                "Each profile carries a confidence badge: Verified (official spec referenced), Standard (consolidated from public sources), Generic (typical OTT template).",
                "Built-in search at the top of the list to filter by name.",
                "« Show specs » button on the active profile: opens a modal window showing the complete spec sheet.",
                "Badge legend at the bottom of the list.",
            ]),
            .h2("Header"),
            .p("The header shows the MisiQC Pro logo, the application name, the version of the loaded spec (e.g. « Annexe CDE 2023-01 »), and a licence status pill (trial in progress, lifetime licence, expired). During the trial period a coloured banner sits at the top of the window with the number of days remaining and a « Buy a license » button that opens Payhip in your browser."),
            .h2("Drop zone and selectors"),
            .bullets([
                "Drop zone: drag and drop a video file (MXF, MOV, MP4, M2V, …) or click to pick one via the native macOS open panel.",
                "Audio variant picker: pills VF / VF+VO / VF+AD / VF+VO+AD. Only variants supported by the selected profile are enabled.",
                "Tolerance card: a reminder of the active signal strictness preset (Pro broadcast / Premium broadcast / EBU R103 / Permissive OTT) with a short explanation.",
                "Stats strip: live counters (duration, file size, detected fps) once the file is loaded.",
            ]),
            .h2("Results panel"),
            .p("Before any analysis, the central panel shows an empty-state inviting you to drop a file. During analysis, a grid of the 16 pipeline stages animates — you see which step is running (probing → GOP → interlace → crop → loudness → phase → audio stats → black detect → silence detect → signal range → freeze detect → duplicate detect → dead pixel → PSE detect → leader → audio pops → metadata extras → finalising). When done, the list of checks is shown with one icon per status: ✓ green (Pass), ⚠ yellow (Warning), ✗ red (Fail)."),
            .h2("Bottom bar"),
            .bullets([
                "Clear: resets the interface to analyse another file.",
                "Export PDF: saves the complete report as an A4 PDF.",
                "Export CSV: saves the results as CSV (two blocks: metadata + checks table + optional signalstats time series).",
                "Export Remediation Guide: generates a PDF containing only failing checks, with recipes for ffmpeg, DaVinci Resolve, Premiere Pro and Avid Media Composer.",
                "Reveal file: opens the Finder on the analysed source file.",
            ]),
            .h2("Menus & keyboard shortcuts"),
            .keyValueTable([
                ("Open file",                    "⌘ O"),
                ("Run analysis",                 "⌘ ⏎"),
                ("Export PDF",                   "⌘ E"),
                ("Export CSV",                   "⇧ ⌘ E"),
                ("Reset analysis",               "⇧ ⌘ R"),
                ("Reveal file",                  "⌘ R"),
                ("Settings",                     "⌘ ,"),
                ("Profile 1 to 9",               "⌘ 1 to ⌘ 9"),
                ("Audio variant 1 to 4",         "⌥ ⌘ 1 to ⌥ ⌘ 4"),
                ("Check for Updates",            "MisiQC Pro menu"),
            ]),
        ]),
        ManualSection(number: 3,
                      title: "Channel profiles & audio variants",
                      elements: [
            .h2("The channel-profile concept"),
            .p("A channel profile is a structured description of a broadcaster's technical spec: which container (MXF OP1a, MOV, MP4, IMF), which video codec (MPEG-2 422P@HL, AVC-Intra 100, ProRes 422 HQ, AVC, HEVC), which resolution and framerate, which audio mapping (number of tracks, languages), which EBU R128 loudness target, which start timecode, which slate, etc."),
            .p("MisiQC Pro ships with 72 ready-to-use profiles, refreshed at every release based on public or consolidated broadcaster specs."),
            .h2("Confidence badges"),
            .bullets([
                "Verified — The spec matches an officially referenced document (FranceTV Annexe CDE 2023, BBC DPP 2017, etc.).",
                "Standard — Spec consolidated from public sources and post-production feedback; sufficient for 99% of deliveries.",
                "Generic — Typical OTT template (1080p HEVC or ProRes 422 HQ) to use when the broadcaster has not published a precise spec.",
            ]),
            .h2("Supported profiles"),
            .columnedList(headline: "Linear TV — France",
                          items: [
                              "France Télévisions", "TF1", "M6", "Canal+ (via OTT)", "ARTE",
                              "C8", "W9", "TMC", "TFX", "BFMTV", "CNews", "LCI",
                              "France 24", "Gulli", "Paris Première", "6ter", "TV5MONDE",
                          ], columns: 3),
            .columnedList(headline: "Linear TV — Europe",
                          items: [
                              "BBC (UK)", "ITV (UK)", "Channel 4 (UK)", "Sky UK",
                              "ARD/ZDF (DE)", "ProSieben (DE)", "RTL (DE)", "Deutsche Welle",
                              "ORF (AT)", "SRG SSR (CH)", "NPO (NL)", "RTBF (BE)", "VRT (BE)",
                              "RAI (IT)", "Mediaset (IT)", "TVE (ES)",
                              "RTP (PT)", "TVP (PL)",
                              "DR (DK)", "SVT (SE)", "NRK (NO)", "YLE (FI)",
                              "EuroNews",
                          ], columns: 3),
            .columnedList(headline: "Linear TV — International",
                          items: [
                              "ABC (US)", "NBC (US)", "CBS (US)", "FOX (US)", "PBS (US)",
                              "CBC (CA)", "TVA (CA)",
                              "Al Jazeera",
                          ], columns: 3),
            .columnedList(headline: "OTT / Streaming",
                          items: [
                              "Netflix", "Amazon Prime Video", "Apple TV+", "Disney+",
                              "HBO Max", "Hulu", "Peacock", "Paramount+", "Pluto TV",
                              "BritBox", "Crunchyroll", "MUBI", "Tubi",
                              "DAZN", "Eurosport",
                          ], columns: 3),
            .columnedList(headline: "Social media & online video",
                          items: [
                              "YouTube", "TikTok", "Instagram", "Facebook",
                              "LinkedIn", "Vimeo", "Twitch",
                          ], columns: 3),
            .columnedList(headline: "Multi-broadcaster reference specs",
                          items: [
                              "DPP (Digital Production Partnership UK)",
                          ], columns: 3),
            .h2("The 4 audio variants"),
            .p("A PAD delivery can contain multiple language versions on different audio tracks. MisiQC Pro recognises 4 typical variants. Each channel profile declares which ones are allowed."),
            .keyValueTable([
                ("VF",          "French Version only. One stereo pair (2 mono tracks: L+R). Minimum delivery for France and French-speaking Belgium."),
                ("VF + VO",     "French + Original Version (usually English). Four mono tracks: VF L, VF R, VO L, VO R. Required by FranceTV for foreign fiction."),
                ("VF + AD",     "French + Audio Description (voice-over describing the action for visually impaired viewers). Four mono tracks: VF L, VF R, AD L, AD R. Mandatory on certain France TV slots."),
                ("VF + VO + AD","All three. Six mono tracks: VF L, VF R, VO L, VO R, AD L, AD R. The most complete case, e.g. requested by ARTE for international fiction."),
            ]),
            .card(title: "Default variant",
                  body: "If you do not explicitly pick a variant, MisiQC Pro applies the default variant (VF) or the first variant the profile allows. You can change the default variant in Settings → General → Default variant.",
                  accent: accentBlue),
        ]),
        ManualSection(number: 4,
                      title: "Running an analysis",
                      elements: [
            .h2("Supported file formats"),
            .p("MisiQC Pro accepts every format readable by ffmpeg / ffprobe (bundled inside the app). The most common in broadcast are:"),
            .bullets([
                ".mxf — MXF OP1a (XDCAM HD422, AVC-Intra, AS-10, RDD9). Reference format for France and UK linear delivery.",
                ".mov — QuickTime (ProRes 422, ProRes 422 HQ, ProRes 4444, AVC). Widely used for premium OTT delivery.",
                ".mp4 — MP4 / ISO BMFF (AVC, HEVC, AAC). Dominant format for mainstream OTT platforms and social media.",
                ".m2v / .ts — MPEG-2 elementary / transport streams (rare today, but supported).",
                "Other recognised containers: .mkv, .imf (Interoperable Master Format), .avi.",
            ]),
            .h2("Step by step"),
            .numbered([
                "Pick the channel profile from the sidebar (or shortcut ⌘ 1 to ⌘ 9).",
                "Drag and drop the video file onto the central drop zone (or ⌘ O for the Finder picker).",
                "Choose the audio variant if the profile offers more than one (⌥ ⌘ 1 to ⌥ ⌘ 4).",
                "Click the « Run » button or press ⌘ ⏎. Analysis starts.",
                "Wait for the pipeline to finish — duration is proportional to the programme's length (~30 sec for 5 min, ~5 min for 1 h).",
            ]),
            .h2("The 16 pipeline stages"),
            .p("During analysis you watch the 16 phases below progress. Each phase runs ffprobe or ffmpeg as a child process, with non-blocking drain of stdout/stderr so the UI never freezes."),
            .keyValueTable([
                ("1. Probing",         "ffprobe extracts all metadata (streams, format, chapters) as JSON."),
                ("2. GOP",             "Parses GOP structure over the first 300 frames (size, open/closed, IBP pattern)."),
                ("3. Interlace",       "idet filter on 600 frames to detect top/bottom field or progressive."),
                ("4. Crop",            "cropdetect spots any letterbox / pillarbox bands."),
                ("5. Loudness",        "ebur128 measures integrated LUFS + True Peak + LRA for each declared stereo pair."),
                ("6. Phase",           "L/R correlation per stereo pair (catches phase inversion or accidental mono)."),
                ("7. Audio Stats",     "DC offset, peak, RMS per audio track. Catches clipping, DC offset, abnormally low ambience."),
                ("8. Black Detect",    "blackdetect finds continuous black segments longer than the configured threshold."),
                ("9. Silence Detect",  "silencedetect finds silence segments longer than the configured threshold, per track."),
                ("10. Signal Range",   "signalstats samples luma and chroma to detect infra-black, super-white and luma excursions."),
                ("11. Freeze Detect",  "Detects frozen segments (strictly identical image for ≥2 seconds)."),
                ("12. Duplicate",      "mpdecimate measures the ratio of duplicate frames (reveals bad 25i/50i reconform or partial freeze)."),
                ("13. Dead Pixels",    "Samples 12 spaced frames with 8-px stride to find dead or stuck pixels."),
                ("14. PSE",            "Photosensitive Epilepsy: detects fast flashes (>3/sec) potentially harmful."),
                ("15. Leader",         "Looks for SMPTE/EBU slates (colour bars + 1 kHz tone) in the first 30 seconds."),
                ("16. Metadata",       "Extra checks: subtitles, HDR metadata (Mastering Display, MaxCLL), AFD, post-roll."),
            ]),
            .card(title: "Cancel an analysis",
                  body: "You can stop the analysis in progress via the « Cancel » button that appears during the pipeline. The ffmpeg/ffprobe child processes are then terminated cleanly with SIGTERM.",
                  accent: accentPeach),
        ]),
        ManualSection(number: 5,
                      title: "Understanding the QC report",
                      elements: [
            .h2("Overall verdict"),
            .p("The report opens with an overall verdict: Pass (✓ green), Warning (⚠ orange) or Fail (✗ red). The overall verdict is the worst status across all checks: a single Fail is enough to flip the overall verdict to Fail. Counters are also shown: N checks passed, M warnings, K failures."),
            .h2("The three statuses"),
            .keyValueTable([
                ("Pass (✓)",     "The check satisfies the broadcaster's spec within tolerance. No action needed."),
                ("Warning (⚠)",  "The check is in a caution zone: the spec is technically respected but on the verge. Watch closely, especially if multiple warnings stack up."),
                ("Fail (✗)",     "The spec is not respected. The file will most likely be rejected by the broadcaster. Fix before delivery."),
            ]),
            .h2("Category: Container"),
            .bullets([
                "Container format (MXF, MOV, MP4, IMF…) — must match the spec exactly.",
                "Operational pattern (OP1a for MXF — a single self-contained file vs OP-Atom which separates video and audio).",
                "Broadcast shim (AS-10 HIGH_HD_2014 for TF1/M6, RDD9 for FranceTV, IMF for premium OTT…).",
            ]),
            .h2("Category: Video"),
            .bullets([
                "Codec — MPEG-2 422P@HL (XDCAM HD422), AVC-Intra 100, ProRes 422 HQ, AVC, HEVC… The expected value is strictly defined per profile.",
                "Profile/level — fine-grained codec conformance (e.g. AVC High@L4.0).",
                "Resolution — 1920×1080 for HD broadcast, 3840×2160 for UHD-1.",
                "Framerate — modelled as a rational num/den (25/1, 30000/1001 for 29.97, 24000/1001 for 23.976) to avoid floating-point false negatives.",
                "Scan mode — interlaced (i) or progressive (p). French broadcast: usually 25i (50 fields/s, top field first).",
                "Video bitrate — 50 Mb/s CBR for most French HD broadcast deliveries, more variable for OTT.",
                "Colour space — BT.709 for HD broadcast, BT.2020/PQ or HLG for HDR.",
                "Colour range — « TV / limited » (16-235 on 8 bits) or « PC / full » (0-255). Wrong range is one of the most frequent errors in broadcast.",
                "GOP — size (typically 12 frames for French broadcast), closed/open, structure (IBBP, IBP).",
            ]),
            .h2("Category: Audio"),
            .bullets([
                "Audio codec — PCM 24-bit 48 kHz for nearly all broadcast deliveries, AAC for OTT.",
                "Track count — must match the chosen variant (2 for VF, 4 for VF+VO or VF+AD, 6 for VF+VO+AD).",
                "Track mapping — for instance track 1 = VF L, track 2 = VF R, track 3 = VO L, track 4 = VO R. Bad mapping inverts stereo or puts the VO on the VF channel.",
                "DC offset — a >1% offset means an upstream audio-chain issue. The app flags it as warning.",
                "L/R phase — correlation between the two channels of a stereo pair. Negative correlation means phase inversion (often a swapped red/white cable in capture).",
                "Audio pops — clicks above the threshold defined by the spec.",
            ]),
            .h2("Category: Loudness EBU R128"),
            .p("EBU R128 measurement is done per stereo pair (via the ffmpeg amerge filter) for each pair declared by the audio mapping. Three quantities are reported:"),
            .bullets([
                "Integrated LUFS — average loudness over the whole programme. Broadcast target: -23 LUFS ± 1 LU for France and Europe, -24 LUFS in the US (ATSC A/85), -16 LUFS for music streaming.",
                "True Peak (dBTP) — true inter-sample peak in dB Full Scale. Broadcast ceiling: -3 dBTP. Above that, saturation risk after transcoding.",
                "LRA (Loudness Range) — difference in LU between the 10th and 95th percentile of the loudness curve. Measures macroscopic dynamics. France TV ceiling: 20 LU (with +5 tolerance).",
            ]),
            .card(title: "Reading the loudness result",
                  body: "For each stereo pair, the report shows the measured value and the target (with its tolerance). If integrated LUFS is -23.4 with a target of -23 ± 1, the check passes. At -21.9 LUFS, it becomes Fail. The same logic applies to True Peak and LRA.",
                  accent: accentMint),
            .h2("Category: Structure"),
            .bullets([
                "Start timecode — 00:00:00:00 for FranceTV/ARTE, 10:00:00:00 for Canal+, 01:00:00:00 for M6/TF1. The TC model handles drop-frame when applicable (North America at 29.97).",
                "File duration — cross-checked against the duration declared in the container metadata.",
                "Slate — search for SMPTE/EBU colour bars and a 1 kHz tone in the first 30 seconds. Required by some broadcasters.",
                "Subtitles — presence of a CEA-608/708 subtitle track or embedded subtitles (per spec).",
                "AFD (Active Format Description) — flag describing the active picture format (4:3, 16:9, letterboxed, etc.).",
                "HDR metadata — Mastering Display Primaries + Max Content Light Level (MaxCLL) + Max Frame Average Light Level (MaxFALL) for HDR10 deliveries.",
                "Post-roll — trailing black, usually 5 seconds after picture. Verified to ensure the programme does not end abruptly on a content frame.",
            ]),
            .h2("Content defects"),
            .bullets([
                "Black — continuous black segments longer than the threshold (default 1 second). A long black in the middle of a programme is suspicious.",
                "Silence — silent segments longer than the threshold (default 1 second) on each audio track. Useful to spot a missing track (fully silent) or audio dropouts.",
                "Frozen frames — strictly identical sequences for ≥ 2 seconds. Reveals a capture signal loss or an encoding bug.",
                "Duplicate frames — ratio of identical frames measured by mpdecimate. A ratio > 5% reveals a bad reconform (e.g. 24p to 25i without pulldown).",
                "Dead pixels — dead or stuck pixels caught by sampling over 12 frames. Rare today in broadcast environments.",
                "PSE (Photosensitive Epilepsy) — detection of fast flashes (>3 flashes/sec) that may trigger seizures in photosensitive viewers. Strict OFCOM/CSA recommendation.",
            ]),
        ]),
        ManualSection(number: 6,
                      title: "Settings & advanced parameters",
                      elements: [
            .h2("Open Settings"),
            .p("Menu MisiQC Pro → Settings… or shortcut ⌘ , — the Settings window opens as a floating panel (640 × 520 px) with four tabs: General, Detection, License, About."),
            .h2("General tab"),
            .keyValueTable([
                ("Interface language",       "French / English / Spanish. Applied instantly (menus, reports, PDF/CSV exports)."),
                ("Default channel profile",  "Profile pre-selected at launch. Convenient if you always work for the same broadcaster."),
                ("Default audio variant",    "Pre-selected when a new file is loaded. Pick VF if you mostly deliver monolingual programmes."),
                ("Reset preferences",        "Destructive button (red) that restores all preferences to factory values. Confirmed by a popup."),
            ]),
            .h2("Detection tab"),
            .bullets([
                "Black detection threshold — minimum duration (0.2 to 10 s, default 1.0 s) for a black segment to be flagged. Lower to 0.5 s if hunting for abrupt cuts.",
                "Silence detection threshold — minimum duration (0.2 to 30 s, default 1.0 s). Raise to 3 s or 5 s on long-form programmes with natural pauses.",
                "Signal range tolerance — controls how strict luma/chroma excursion checks are (super-white, infra-black). Four presets detailed below.",
            ]),
            .h2("The 4 signal-range tolerance levels"),
            .keyValueTable([
                ("Pro broadcast (strict)",
                 "Zero tolerance for luma excursion. Aim for this level for France TV, ARTE, BBC: Pass if <0.1% of out-of-range pixels, Warning if <0.5%."),
                ("Premium broadcast (recommended)",
                 "Codec tolerance: a small overshoot is allowed. Pass if <0.5%, Warning if <1%. Default setting, fits most deliveries."),
                ("EBU R103 v3.0 (official norm)",
                 "Strictly applies the EBU R103 v3.0 thresholds: Pass if <1%, Warning if <2%. Useful to validate a delivery against the standard without interpretation."),
                ("Permissive OTT (Netflix, Amazon…)",
                 "Very lenient. Pass if <5%, Warning if <1%. Suits OTT deliveries that re-transcode to multiple targets afterwards."),
            ]),
            .h2("License tab"),
            .p("Licence status at the top (trial / lifetime license / expired), key input field in monospace, 40/40 counter, Activate / Buy a license / Deactivate license buttons (the last one visible only when a licence is active)."),
            .h2("About tab"),
            .p("MisiQC Pro logo, application name, short description of the value proposition, link to www.misiraca.com, app version."),
        ]),
        ManualSection(number: 7,
                      title: "Exports: PDF, remediation guide, CSV",
                      elements: [
            .h2("PDF report"),
            .p("The PDF report is meant to be archived, shared with the broadcaster, or attached to a delivery email. A4 portrait format, rendered natively via PDFKit."),
            .bullets([
                "Cover page: file name, channel profile (with spec version), analysis date, overall verdict with Pass/Warning/Fail counters.",
                "File metadata: duration, size, detected framerate, codec, etc.",
                "Per-category table: Container, Video, Audio, Loudness, Structure, Content, with label / expected value / measured value / status.",
                "Optional landscape page: signal-range timeline (curve over the programme's duration) when the time-series has been sampled.",
                "Footer: app version, profile version, traceability watermark.",
            ]),
            .h2("Watermark"),
            .keyValueTable([
                ("Trial period",     "« REPORT GENERATED IN TRIAL MODE » in the footer (discreet grey)."),
                ("Active licence",   "« License: XXXXX · Host: Mac-Name » — first 5 characters of the key + machine name. Allows tracing unauthorised sharing."),
                ("Trial expired",    "The PDF cannot be exported while the trial is expired and no licence is activated."),
            ]),
            .h2("Remediation guide"),
            .p("The remediation guide is a complementary PDF generated on demand. It only includes failing checks (Fail status) with, for each, concrete remediation recipes."),
            .bullets([
                "Cover page: source file summary, number of issues to fix, liability disclaimer.",
                "One card per failure: check label, technical cause, software-specific recipes.",
                "ffmpeg recipes (exact terminal command to run).",
                "DaVinci Resolve recipes (Color Science menu, Project Settings, Deliver tab).",
                "Adobe Premiere Pro recipes (Effects panels, Lumetri Color, Audio Mixer, Export Media).",
                "Avid Media Composer recipes (export modules, PCM settings, Source Settings).",
                "Links to the official broadcaster and software vendor docs where relevant.",
            ]),
            .card(title: "When to use the remediation guide?",
                  body: "When your main report contains one or more failures, export the remediation guide and hand it to the colourist / mixer / editor. They can apply the recipe for the software they use without having to interpret the broadcaster's spec.",
                  accent: accentBlue),
            .h2("CSV export"),
            .p("The CSV is intended for spreadsheet workflows (Excel, Numbers, Google Sheets) or scripting (pandas, R). Three blocks:"),
            .bullets([
                "Block 1 — Metadata: File, Profile, Analyzed at, Verdict, Pass/Warning/Fail counters.",
                "Block 2 — Check table: columns Category, Label, Expected, Actual, Status, Detail.",
                "Block 3 (optional) — signalstats time series sampled every N frames: pts_sec, YAVG, YMIN, YMAX, BRNG, TOUT, VREP. Directly importable into pandas to plot the timeline.",
            ]),
        ]),
        ManualSection(number: 8,
                      title: "License, updates & support",
                      elements: [
            .h2("Lifetime licence"),
            .bullets([
                "One key, valid for life, on all your personal Macs.",
                "No hardware limitation, no server call for validation: 100% offline.",
                "Major updates are included in the lifetime licence.",
                "You can transfer your licence by deactivating on one Mac (Settings → License → Deactivate) then reactivating on another.",
            ]),
            .h2("Automatic updates (Sparkle)"),
            .bullets([
                "MisiQC Pro embeds Sparkle 2.x, the standard auto-update framework for macOS apps outside the Mac App Store.",
                "At every launch, the app checks in the background whether a new version is available.",
                "You can force a check via menu MisiQC Pro → Check for Updates…",
                "Updates are signed with a dedicated Ed25519 key. An update not signed by my Mac is rejected by Sparkle — no risk of a malicious fake update.",
                "The update is applied when the app restarts, without losing your licence or preferences.",
            ]),
            .h2("Support & contact"),
            .keyValueTable([
                ("Email",          "contact@misiraca.com — reply within 48 h on business days."),
                ("Website",        "www.misiraca.com — news and release notes."),
                ("Bug reports",    "Please specify: app version (Menu MisiQC Pro → About), macOS version, problem description, and ideally a small (≤30 s) video sample that reproduces the bug."),
                ("Feature requests","Welcome — give the broadcast context (channel, programme type) to help prioritise."),
            ]),
            .h2("Frequently asked questions"),
            .card(title: "Analysis is very slow on a long programme — is that normal?",
                  body: "Yes, analysis duration is proportional to the programme's length. For a 1 h 30, expect ~10 minutes. The app runs the entire file through several ffmpeg filters (ebur128, signalstats, mpdecimate, etc.) — that depth is inherent to the checks.",
                  accent: accentBlue),
            .card(title: "My MXF fails on the « shim » check while video values look fine.",
                  body: "The shim (AS-10 HIGH_HD_2014, RDD9, etc.) is a label carried by the MXF container metadata. If your encoder does not set the shim explicitly, it will be flagged as missing even if everything else is compliant. Fix: re-encode with a chain that sets the shim explicitly, or use a dedicated MXF re-wrapper.",
                  accent: accentPeach),
            .card(title: "The loudness check shows -22.7 LUFS for a -23 ± 1 target. Why Pass and not Warning?",
                  body: "Because -22.7 LUFS sits inside the tolerance window (-24 to -22 LUFS). The check becomes Warning near the borders (for instance -22.0 or -23.95) and Fail beyond. The Warning zone is defined per channel profile.",
                  accent: accentBlue),
            .card(title: "Can I analyse a file directly from a network share?",
                  body: "Yes, as long as macOS has mounted the share (SMB, AFP, NFS). MisiQC Pro reads the file via standard Foundation APIs. A slow network will proportionally slow the analysis.",
                  accent: accentBlue),
            .card(title: "What if I lose my key?",
                  body: "No worries: your Payhip purchase is tied to your email. Email contact@misiraca.com mentioning the email used for the purchase and I will resend your key.",
                  accent: accentMint),
            .h2("Licence terms"),
            .bullets([
                "✅ Unlimited personal and professional use on your Macs.",
                "✅ Unlimited PDF / CSV / remediation guide generation.",
                "✅ Minor and major updates included for life.",
                "❌ Resale, sharing or distribution of the key is forbidden.",
                "❌ Reverse-engineering, disassembly or bypassing the licence check is forbidden.",
                "Unauthorised key sharing may be traced via the watermarks of generated PDF reports.",
            ]),
            .h2("Credits"),
            .p("MisiQC Pro is designed and developed by Matthieu Misiraca in Paris. The application relies on ffmpeg and ffprobe (LGPL), Sparkle 2.x (BSD), and Apple's SwiftUI / CryptoKit ecosystem."),
            .spacer(8),
            .card(title: "Thanks for your trust",
                  body: "And happy quality checking! Feel free to write me with any question, suggestion or production feedback.\n— Matthieu",
                  accent: accentViolet),
        ]),
    ]
)

// MARK: - Content : ESPAÑOL

let strES = LangStrings(
    subtitle: "Manual de usuario — Control de calidad PAD broadcast y OTT",
    welcome: "Bienvenido 🎬 — tienes en tus manos el manual completo de MisiQC Pro, la herramienta de control de calidad automatizado de archivos PAD para difusión lineal (TV) y plataformas OTT.",
    coverIntroTitle: "Acerca de este manual",
    coverIntroBody: "Este manual describe paso a paso la instalación, la activación de la licencia, la interfaz, los 72 perfiles de canales y plataformas compatibles, las variantes de audio, el pipeline de análisis completo, la lectura del informe QC, las exportaciones (PDF, CSV, guía de corrección) y todos los ajustes avanzados. Manténlo a mano: sirve como referencia para descifrar cada resultado mostrado por la aplicación.",
    tocTitle: "Índice",
    tocEntries: [
        "Presentación, instalación y activación",
        "Recorrido por la interfaz",
        "Perfiles de canal y variantes de audio",
        "Lanzar un análisis",
        "Comprender el informe QC",
        "Ajustes y parámetros avanzados",
        "Exportaciones: PDF, guía de corrección, CSV",
        "Licencia, actualizaciones y soporte",
    ],
    sectionWord: "Sección",
    footerLabel: "Manual de usuario",
    sections: [
        ManualSection(number: 1,
                      title: "Presentación, instalación y activación",
                      elements: [
            .h2("¿Qué es MisiQC Pro?"),
            .p("MisiQC Pro es una aplicación macOS nativa, no sandboxed, diseñada para el control de calidad automatizado de archivos PAD (Prêt À Diffuser, masters listos para difundir) destinados a cadenas de televisión lineal (France TV, ARTE, TF1, M6, BBC, Canal+, etc.) y plataformas OTT (Netflix, Amazon Prime Video, Disney+, Apple TV+, etc.)."),
            .p("Extrae los metadatos técnicos del archivo (contenedor, códec, resolución, framerate, GOP, mapeo de audio, código de tiempo…), mide la conformidad de loudness EBU R128 (LUFS integrada, True Peak, LRA), detecta defectos de contenido (negros, silencios, dead pixels, frames duplicados, frames congelados, eventos fotosensibles), y luego compara cada medición con el pliego de condiciones oficial del difusor seleccionado. El veredicto se entrega en menos de un minuto para la mayoría de los programas."),
            .card(title: "¿Por qué un manual?",
                  body: "El informe generado por MisiQC Pro es denso: más de 30 controles, mediciones EBU R128, series temporales. Este manual da el significado exacto de cada línea, el razonamiento detrás de cada umbral y las recomendaciones de corrección cuando un control falla.",
                  accent: accentBlue),
            .h2("Requisitos del sistema"),
            .keyValueTable([
                ("Sistema",         "macOS 14 (Sonoma) o posterior · Apple Silicon o Intel"),
                ("Espacio en disco","~150 MB para la aplicación · espacio libre proporcional a los archivos analizados"),
                ("Memoria RAM",     "8 GB mínimo recomendado"),
                ("Red",             "Conexión a Internet requerida solo para las actualizaciones Sparkle y la activación inicial"),
                ("Permisos",        "Acceso de solo lectura a los archivos analizados (la app nunca escribe en las fuentes)"),
            ]),
            .h2("Instalación"),
            .numbered([
                "Ve a la página oficial de descarga: https://github.com/misilab/misiqcpro/releases/latest",
                "Descarga el archivo MisiQC-Pro-X.Y.Z.dmg (~65 MB). Está firmado con mi Apple Developer ID y notarizado por Apple — sin alerta bloqueante de Gatekeeper en el primer lanzamiento.",
                "Haz doble clic en el DMG. Aparece una ventana con MisiQC Pro a la izquierda y un acceso directo Aplicaciones a la derecha.",
                "Arrastra MisiQC Pro al acceso directo Aplicaciones. La instalación ha terminado.",
                "Inicia la aplicación desde Launchpad o desde el Finder → carpeta Aplicaciones.",
            ]),
            .card(title: "Período de prueba",
                  body: "En el primer lanzamiento, MisiQC Pro inicia un período de prueba gratuito de 7 días. Todas las funciones están disponibles, incluidas las exportaciones PDF, CSV y guía de corrección. Pasados los 7 días, la aplicación sigue siendo utilizable para ver los informes, pero las exportaciones se desactivan hasta que se active una licencia.",
                  accent: accentMint),
            .h2("Activación de tu licencia"),
            .p("Después de tu compra en Payhip, recibes por correo electrónico una clave de 47 caracteres con la forma: XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX (8 grupos de 5 separados por guiones)."),
            .numbered([
                "Abre MisiQC Pro.",
                "Menú MisiQC Pro → Ajustes… (atajo ⌘ ,).",
                "Haz clic en la pestaña 🔑 Licencia.",
                "Copia la clave completa desde el correo (⌘C).",
                "Pega (⌘V) en el campo « Clave de licencia (del email) ». El contador bajo el campo debe mostrar 40 / 40 en verde.",
                "Haz clic en Activar. El mensaje « ¡Gracias! Licencia de por vida activa. » confirma el éxito.",
            ]),
            .card(title: "En caso de error",
                  body: "« Clave incompleta (X/40 caracteres) » → tu copiar/pegar es parcial; selecciona la clave entera desde el correo y vuelve a copiarla.\n« Firma inválida » → la clave se ha alterado (carácter faltante o añadido). Solicita una nueva clave en contact@misiraca.com.\n« Formato de clave no reconocido » → tu versión de MisiQC Pro es demasiado antigua; actualiza desde el menú MisiQC Pro → Buscar actualizaciones…",
                  accent: accentPeach),
            .h2("Multi-Mac y almacenamiento de la clave"),
            .bullets([
                "Tu clave es válida en todos tus Macs personales — sin limitación de hardware.",
                "La clave se almacena cifrada en tu Llavero de macOS (kSecAttrAccessibleAfterFirstUnlock).",
                "Puedes desactivar la licencia en cualquier momento desde la pestaña Licencia → botón « Desactivar la licencia ». Útil para transferir la clave a otro Mac o volver al modo de prueba.",
                "No se necesita ninguna conexión al servidor para validar la clave: la verificación se realiza localmente mediante HMAC-SHA256 contra un secreto embebido en la aplicación.",
            ]),
        ]),
        ManualSection(number: 2,
                      title: "Recorrido por la interfaz",
                      elements: [
            .h2("Disposición general"),
            .p("La ventana principal de MisiQC Pro adopta una disposición de dos columnas, optimizada para pantallas grandes (tamaño ideal 1500 × 1020 px, redimensionable). A la izquierda está la barra lateral de selección de perfil de canal, a la derecha la zona de trabajo donde se deposita el archivo, se elige la variante de audio y se consulta el informe."),
            .h2("Barra lateral (izquierda)"),
            .bullets([
                "Lista de los 72 perfiles de canales / plataformas, agrupados lógicamente: TV Francia, TV Europa, TV Internacional, OTT, Redes sociales.",
                "Cada perfil muestra una insignia de confianza: Verificado (especificación oficial referenciada), Estándar (consolidado público), Genérico (plantilla típica OTT).",
                "Búsqueda integrada en la parte superior de la lista para filtrar por nombre.",
                "Botón « Ver especificaciones » en el perfil activo: abre una ventana modal detallada con el pliego completo.",
                "Leyenda de insignias en la parte inferior de la lista.",
            ]),
            .h2("Cabecera"),
            .p("La cabecera muestra el logo de MisiQC Pro, el nombre de la aplicación, la versión del pliego cargado (p. ej. « Annexe CDE 2023-01 ») y un panel de estado de licencia (prueba en curso, licencia activa, expirada). Durante el período de prueba, una franja de color aparece en la parte superior de la ventana con el número de días restantes y un botón « Comprar una licencia » que abre Payhip en el navegador."),
            .h2("Zona de arrastre y selectores"),
            .bullets([
                "Zona de arrastre: arrastra y suelta un archivo de vídeo (MXF, MOV, MP4, M2V, …) o haz clic para elegirlo mediante el selector nativo macOS.",
                "Selector de variante de audio: pestillos VF / VF+VO / VF+AD / VF+VO+AD. Solo las variantes previstas por el perfil seleccionado son activables.",
                "Panel Tolerancia: recordatorio del nivel de tolerancia de señal activo (Pro broadcast / Premium broadcast / EBU R103 / Permisivo OTT) con explicación breve.",
                "Stats strip: contadores en tiempo real (duración, tamaño, fps detectado) cuando el archivo está cargado.",
            ]),
            .h2("Panel de resultados"),
            .p("Mientras no se lanza ningún análisis, el panel central muestra un estado vacío invitando a soltar un archivo. Durante el análisis, una cuadrícula de las 16 etapas del pipeline se anima — se ve en tiempo real qué fase está en curso (probing → GOP → entrelazado → recorte → loudness → fase → audio stats → detección de negros → detección de silencios → rango de señal → detección de freeze → duplicados → dead pixels → PSE → leader → audio pops → metadatos extras → finalización). Una vez terminado el análisis, se muestra la lista de controles con un icono por estado: ✓ verde (Pass), ⚠ amarillo (Warning), ✗ rojo (Fail)."),
            .h2("Barra inferior"),
            .bullets([
                "Borrar: restablece la interfaz para analizar otro archivo.",
                "Exportar PDF: guarda el informe completo como PDF A4.",
                "Exportar CSV: guarda los resultados en formato CSV (dos bloques: metadatos + tabla de controles + opcionalmente serie temporal signalstats).",
                "Exportar guía de corrección: genera un PDF que solo incluye los controles fallidos, con recetas para ffmpeg, DaVinci Resolve, Premiere Pro y Avid Media Composer.",
                "Revelar archivo: abre el Finder en el archivo analizado.",
            ]),
            .h2("Menús y atajos de teclado"),
            .keyValueTable([
                ("Abrir archivo",            "⌘ O"),
                ("Lanzar análisis",          "⌘ ⏎"),
                ("Exportar PDF",             "⌘ E"),
                ("Exportar CSV",             "⇧ ⌘ E"),
                ("Reiniciar análisis",       "⇧ ⌘ R"),
                ("Revelar archivo",          "⌘ R"),
                ("Ajustes",                  "⌘ ,"),
                ("Perfil 1 a 9",             "⌘ 1 a ⌘ 9"),
                ("Variante audio 1 a 4",     "⌥ ⌘ 1 a ⌥ ⌘ 4"),
                ("Buscar actualizaciones",   "Menú MisiQC Pro"),
            ]),
        ]),
        ManualSection(number: 3,
                      title: "Perfiles de canal y variantes de audio",
                      elements: [
            .h2("El concepto de perfil de canal"),
            .p("Un perfil de canal es una descripción estructurada del pliego técnico de un difusor: qué contenedor (MXF OP1a, MOV, MP4, IMF), qué códec de vídeo (MPEG-2 422P@HL, AVC-Intra 100, ProRes 422 HQ, AVC, HEVC), qué resolución y framerate, qué mapeo de audio (número de pistas, idiomas), qué objetivo de loudness EBU R128, qué código de tiempo de inicio, qué leader, etc."),
            .p("MisiQC Pro incluye 72 perfiles listos para usar, actualizados en cada versión del software a partir de los pliegos públicos o consolidados de los difusores."),
            .h2("Insignias de confianza"),
            .bullets([
                "Verificado — La especificación corresponde a un documento oficial referenciado (FranceTV Annexe CDE 2023, BBC DPP 2017, etc.).",
                "Estándar — Especificación consolidada a partir de fuentes públicas y retroalimentación de postproducción; suficiente para el 99 % de las entregas.",
                "Genérico — Plantilla OTT típica (1080p HEVC o ProRes 422 HQ) para usar cuando el difusor no ha publicado una especificación precisa.",
            ]),
            .h2("Lista de perfiles compatibles"),
            .columnedList(headline: "TV lineal — Francia",
                          items: [
                              "France Télévisions", "TF1", "M6", "Canal+ (vía OTT)", "ARTE",
                              "C8", "W9", "TMC", "TFX", "BFMTV", "CNews", "LCI",
                              "France 24", "Gulli", "Paris Première", "6ter", "TV5MONDE",
                          ], columns: 3),
            .columnedList(headline: "TV lineal — Europa",
                          items: [
                              "BBC (UK)", "ITV (UK)", "Channel 4 (UK)", "Sky UK",
                              "ARD/ZDF (DE)", "ProSieben (DE)", "RTL (DE)", "Deutsche Welle",
                              "ORF (AT)", "SRG SSR (CH)", "NPO (NL)", "RTBF (BE)", "VRT (BE)",
                              "RAI (IT)", "Mediaset (IT)", "TVE (ES)",
                              "RTP (PT)", "TVP (PL)",
                              "DR (DK)", "SVT (SE)", "NRK (NO)", "YLE (FI)",
                              "EuroNews",
                          ], columns: 3),
            .columnedList(headline: "TV lineal — Internacional",
                          items: [
                              "ABC (US)", "NBC (US)", "CBS (US)", "FOX (US)", "PBS (US)",
                              "CBC (CA)", "TVA (CA)",
                              "Al Jazeera",
                          ], columns: 3),
            .columnedList(headline: "OTT / Streaming",
                          items: [
                              "Netflix", "Amazon Prime Video", "Apple TV+", "Disney+",
                              "HBO Max", "Hulu", "Peacock", "Paramount+", "Pluto TV",
                              "BritBox", "Crunchyroll", "MUBI", "Tubi",
                              "DAZN", "Eurosport",
                          ], columns: 3),
            .columnedList(headline: "Redes sociales y vídeo en línea",
                          items: [
                              "YouTube", "TikTok", "Instagram", "Facebook",
                              "LinkedIn", "Vimeo", "Twitch",
                          ], columns: 3),
            .columnedList(headline: "Especificaciones de referencia multi-difusor",
                          items: [
                              "DPP (Digital Production Partnership UK)",
                          ], columns: 3),
            .h2("Las 4 variantes de audio"),
            .p("Una entrega PAD puede contener varias versiones lingüísticas en pistas de audio distintas. MisiQC Pro reconoce 4 variantes típicas. Cada perfil de canal declara cuáles están permitidas."),
            .keyValueTable([
                ("VF",          "Versión Francesa solamente. Un par estéreo (2 pistas mono: L+R). Entrega mínima para Francia y Bélgica francófona."),
                ("VF + VO",     "Versión Francesa + Versión Original (generalmente inglés). Cuatro pistas mono: VF L, VF R, VO L, VO R. Exigida por FranceTV para ficciones extranjeras."),
                ("VF + AD",     "Versión Francesa + Audio Descripción (voz en off que describe la acción para personas con discapacidad visual). Cuatro pistas mono: VF L, VF R, AD L, AD R. Obligatoria en ciertas franjas horarias en Francia."),
                ("VF + VO + AD","Acumulación de las tres. Seis pistas mono: VF L, VF R, VO L, VO R, AD L, AD R. El caso más completo, exigido por ejemplo por ARTE para ficciones internacionales."),
            ]),
            .card(title: "Variante por defecto",
                  body: "Si no se selecciona explícitamente ninguna variante, MisiQC Pro aplica la variante por defecto (VF) o la primera variante permitida por el perfil. Puedes cambiar la variante por defecto en Ajustes → General → Variante por defecto.",
                  accent: accentBlue),
        ]),
        ManualSection(number: 4,
                      title: "Lanzar un análisis",
                      elements: [
            .h2("Formatos de archivo compatibles"),
            .p("MisiQC Pro acepta todos los formatos legibles por ffmpeg / ffprobe (integrados en la aplicación). Los más frecuentes en broadcast son:"),
            .bullets([
                ".mxf — MXF OP1a (XDCAM HD422, AVC-Intra, AS-10, RDD9). Formato de referencia para difusión lineal en Francia y Reino Unido.",
                ".mov — QuickTime (ProRes 422, ProRes 422 HQ, ProRes 4444, AVC). Muy usado para entregas OTT premium.",
                ".mp4 — MP4 / ISO BMFF (AVC, HEVC, AAC). Formato dominante para plataformas OTT mainstream y redes sociales.",
                ".m2v / .ts — flujos MPEG-2 transport / elemental (raros hoy, pero compatibles).",
                "Otros contenedores reconocidos: .mkv, .imf (Interoperable Master Format), .avi.",
            ]),
            .h2("Lanzar el análisis, paso a paso"),
            .numbered([
                "Selecciona el perfil de canal en la barra lateral (o atajo ⌘ 1 a ⌘ 9).",
                "Arrastra y suelta el archivo de vídeo en la zona de arrastre central (o ⌘ O para el selector Finder).",
                "Elige la variante de audio si el perfil ofrece varias (⌥ ⌘ 1 a ⌥ ⌘ 4).",
                "Haz clic en el botón « Lanzar » o ⌘ ⏎. El análisis comienza.",
                "Espera a que termine el pipeline — la duración es proporcional a la del programa (~30 s para 5 min, ~5 min para 1 h).",
            ]),
            .h2("Las 16 etapas del pipeline"),
            .p("Durante el análisis se ven progresar las 16 fases siguientes. Cada fase usa ffprobe o ffmpeg en subproceso, con drenaje no bloqueante de stdout/stderr para no congelar la interfaz."),
            .keyValueTable([
                ("1. Probing",         "ffprobe extrae todos los metadatos (streams, format, chapters) como JSON."),
                ("2. GOP",             "Analiza la estructura GOP en los primeros 300 frames (tamaño, abierto/cerrado, patrón IBP)."),
                ("3. Entrelazado",     "Filtro idet sobre 600 frames para detectar campo superior/inferior o progresivo."),
                ("4. Recorte",         "cropdetect identifica eventuales franjas negras (letterbox / pillarbox)."),
                ("5. Loudness",        "ebur128 mide LUFS integrada + True Peak + LRA para cada par estéreo declarado."),
                ("6. Fase",            "Correlación L/R por par estéreo (detecta inversión de fase o mono accidental)."),
                ("7. Audio Stats",     "DC offset, peak, RMS por pista de audio. Detecta clipping, offset DC, ambientes demasiado bajos."),
                ("8. Detección negros","blackdetect identifica segmentos negros continuos superiores al umbral configurado."),
                ("9. Detección silencios","silencedetect identifica silencios superiores al umbral configurado, en cada pista."),
                ("10. Rango de señal", "signalstats muestrea luminancia y crominancia para detectar infra-black, super-white y excursiones Y."),
                ("11. Freeze",         "Detección de secuencias congeladas (imagen estrictamente idéntica durante ≥2 segundos)."),
                ("12. Duplicados",     "mpdecimate mide la proporción de frames duplicados (revela un mal reconform 25i/50i o un freeze parcial)."),
                ("13. Dead pixels",    "Muestreo de 12 frames espaciados con stride de 8 px para detectar píxeles muertos o atascados."),
                ("14. PSE",            "Photosensitive Epilepsy: detecta destellos rápidos (>3/segundo) potencialmente peligrosos."),
                ("15. Leader",         "Búsqueda de leaders SMPTE/EBU (barras de color + tono 1 kHz) en los primeros 30 segundos."),
                ("16. Metadatos",      "Verificaciones complementarias: subtítulos, metadatos HDR (Mastering Display, MaxCLL), AFD, post-roll."),
            ]),
            .card(title: "Cancelar un análisis",
                  body: "Puedes detener el análisis en curso con el botón « Cancelar » que aparece durante el pipeline. Los subprocesos ffmpeg/ffprobe se terminan limpiamente con SIGTERM.",
                  accent: accentPeach),
        ]),
        ManualSection(number: 5,
                      title: "Comprender el informe QC",
                      elements: [
            .h2("Veredicto general"),
            .p("El informe se abre con un veredicto general: Pass (✓ verde), Warning (⚠ naranja) o Fail (✗ rojo). El veredicto general corresponde al peor estado entre todos los controles: un solo Fail basta para que el veredicto general sea Fail. También se muestran los contadores: N controles pasados, M avisos, K fallos."),
            .h2("Los tres estados"),
            .keyValueTable([
                ("Pass (✓)",     "El control satisface la especificación del difusor dentro de las tolerancias. No se requiere acción."),
                ("Warning (⚠)",  "El control está en una zona de alerta: la especificación se respeta técnicamente pero al límite. Vigilar, sobre todo si se acumulan varios avisos."),
                ("Fail (✗)",     "La especificación no se respeta. El archivo será probablemente rechazado por el difusor. Corregir antes de entregar."),
            ]),
            .h2("Categoría: Contenedor"),
            .bullets([
                "Formato del contenedor (MXF, MOV, MP4, IMF…) — debe coincidir exactamente con la especificación.",
                "Patrón operacional (OP1a para MXF — un único archivo autocontenido vs OP-Atom que separa vídeo y audio).",
                "Shim broadcast (AS-10 HIGH_HD_2014 para TF1/M6, RDD9 para FranceTV, IMF para OTT premium…).",
            ]),
            .h2("Categoría: Vídeo"),
            .bullets([
                "Códec — MPEG-2 422P@HL (XDCAM HD422), AVC-Intra 100, ProRes 422 HQ, AVC, HEVC… El valor esperado se define estrictamente por perfil.",
                "Profile/level — precisa la conformidad fina del códec (p. ej. AVC High@L4.0).",
                "Resolución — 1920×1080 para HD broadcast, 3840×2160 para UHD-1.",
                "Framerate — modelado como un racional num/den (25/1, 30000/1001 para 29,97, 24000/1001 para 23,976) para evitar falsos negativos decimales.",
                "Modo de barrido — entrelazado (i) o progresivo (p). En broadcast francés: generalmente 25i (50 campos/s, campo superior primero).",
                "Bitrate vídeo — 50 Mb/s CBR para la mayoría de los difusores HD broadcast franceses, más variable para OTT.",
                "Espacio colorimétrico — BT.709 para HD broadcast, BT.2020/PQ o HLG para HDR.",
                "Rango colorimétrico — « TV / limited » (16-235 en 8 bits) o « PC / full » (0-255). El rango incorrecto es uno de los errores más frecuentes en broadcast.",
                "GOP — tamaño (generalmente 12 frames para broadcast francés), cerrado/abierto, estructura (IBBP, IBP).",
            ]),
            .h2("Categoría: Audio"),
            .bullets([
                "Códec de audio — PCM 24-bit 48 kHz para la casi totalidad de entregas broadcast, AAC para OTT.",
                "Número de pistas — debe corresponder a la variante elegida (2 para VF, 4 para VF+VO o VF+AD, 6 para VF+VO+AD).",
                "Mapeo de pistas — por ejemplo, pista 1 = VF L, pista 2 = VF R, pista 3 = VO L, pista 4 = VO R. Un mapeo erróneo invierte el estéreo o coloca la VO en el canal VF.",
                "DC offset — un offset >1 % indica un problema en la cadena de audio aguas arriba. La app lo marca como warning.",
                "Fase L/R — correlación entre los dos canales de un par estéreo. Una correlación negativa señala inversión de fase (a menudo un cable rojo/blanco invertido en captura).",
                "Audio pops — clics audio superiores al umbral definido por la especificación.",
            ]),
            .h2("Categoría: Loudness EBU R128"),
            .p("La medición EBU R128 se realiza por par estéreo (mediante el filtro amerge de ffmpeg) para cada par declarado en el mapeo de audio. Se entregan tres magnitudes:"),
            .bullets([
                "LUFS integrada — nivel de loudness medio sobre toda la duración del programa. Objetivo broadcast: -23 LUFS ± 1 LU para Francia y Europa, -24 LUFS en EE.UU. (ATSC A/85), -16 LUFS para streaming musical.",
                "True Peak (dBTP) — pico verdadero inter-muestra. Techo broadcast: -3 dBTP. Por encima, riesgo de saturación tras transcodificación.",
                "LRA (Loudness Range) — diferencia en LU entre el percentil 10 y el 95 de la curva de loudness. Mide la dinámica macroscópica. Techo France TV: 20 LU (con tolerancia +5).",
            ]),
            .card(title: "Lectura del resultado loudness",
                  body: "Para cada par estéreo, el informe muestra el valor medido y el objetivo (con su tolerancia). Si la LUFS integrada es -23,4 LUFS con un objetivo -23 ± 1, el control pasa. A -21,9 LUFS pasa a Fail. La misma lógica se aplica a True Peak y LRA.",
                  accent: accentMint),
            .h2("Categoría: Estructura"),
            .bullets([
                "Código de tiempo de inicio — 00:00:00:00 para FranceTV/ARTE, 10:00:00:00 para Canal+, 01:00:00:00 para M6/TF1. La modelización del TC incluye el drop-frame cuando corresponde (Norteamérica a 29,97).",
                "Duración del archivo — verificada contra la duración declarada en los metadatos del contenedor (coherencia).",
                "Leaders — búsqueda de barras de color SMPTE/EBU y de un tono 1 kHz en los primeros 30 segundos. Solicitado por algunos canales.",
                "Subtítulos — presencia de pista de subtítulos CEA-608/708 o subtítulos embebidos (según especificación).",
                "AFD (Active Format Description) — bandera que describe el formato activo (4:3, 16:9, letterbox, etc.).",
                "Metadatos HDR — Mastering Display Primaries + Max Content Light Level (MaxCLL) + Max Frame Average Light Level (MaxFALL) para entregas HDR10.",
                "Post-roll — negro final, generalmente 5 segundos tras la imagen. Verificado para asegurar que el programa no termina abruptamente sobre un frame de contenido.",
            ]),
            .h2("Defectos de contenido"),
            .bullets([
                "Negros — segmentos negros continuos más largos que el umbral (por defecto 1 segundo). Un negro largo en mitad de un programa es sospechoso.",
                "Silencios — segmentos silenciosos más largos que el umbral (por defecto 1 segundo) en cada pista de audio. Permite detectar una pista ausente (totalmente silenciosa) o huecos de audio.",
                "Frames congelados (freeze) — secuencias estrictamente idénticas durante ≥ 2 segundos. Revela una pérdida de señal en captura o un bug de codificación.",
                "Frames duplicados — proporción de frames idénticos medida por mpdecimate. Un ratio > 5 % revela un mal reconform (por ejemplo 24p a 25i sin pulldown).",
                "Dead pixels — píxeles muertos o atascados detectados por muestreo en 12 frames. Raros hoy en entorno broadcast.",
                "PSE (Photosensitive Epilepsy) — detección de destellos rápidos (>3 destellos/segundo) que pueden provocar crisis en personas fotosensibles. Recomendación estricta OFCOM/CSA.",
            ]),
        ]),
        ManualSection(number: 6,
                      title: "Ajustes y parámetros avanzados",
                      elements: [
            .h2("Abrir los Ajustes"),
            .p("Menú MisiQC Pro → Ajustes… o atajo ⌘ , — la ventana de Ajustes se abre en modo flotante (640 × 520 px) con cuatro pestañas: General, Detección, Licencia, Acerca de."),
            .h2("Pestaña General"),
            .keyValueTable([
                ("Idioma de la interfaz",      "Francés / Inglés / Español. El cambio se aplica instantáneamente (menús, informes, exportaciones PDF/CSV)."),
                ("Perfil de canal por defecto","Perfil preseleccionado al inicio de la aplicación. Útil si trabajas siempre para el mismo canal."),
                ("Variante audio por defecto", "Preseleccionada al cargar un nuevo archivo. Elige VF si entregas mayoritariamente programas monolingües."),
                ("Reiniciar preferencias",     "Botón destructivo (rojo) que restaura todas las preferencias a su valor de fábrica. Confirmado por un cuadro de diálogo."),
            ]),
            .h2("Pestaña Detección"),
            .bullets([
                "Umbral de detección de negros — duración mínima (0,2 a 10 s, por defecto 1,0 s) para que un segmento negro sea señalado. Reduce a 0,5 s si buscas cortes abruptos.",
                "Umbral de detección de silencios — duración mínima (0,2 a 30 s, por defecto 1,0 s). Aumenta a 3 s o 5 s en programas largos con respiraciones naturales.",
                "Nivel de tolerancia signal range — regula la agresividad de los controles de excursión luma/croma (super-white, infra-black). Cuatro presets detallados a continuación.",
            ]),
            .h2("Los 4 niveles de tolerancia signal range"),
            .keyValueTable([
                ("Pro broadcast (estricto)",
                 "Tolerancia cero para excursiones luma. Apunta a este nivel para France TV, ARTE, BBC: Pass si <0,1% de píxeles fuera de rango, Warning si <0,5%."),
                ("Premium broadcast (recomendado)",
                 "Tolerancia códec: se admite un ligero desbordamiento. Pass si <0,5%, Warning si <1%. Es el ajuste por defecto, válido para la mayoría de entregas."),
                ("EBU R103 v3.0 (norma oficial)",
                 "Aplica estrictamente los umbrales de la norma EBU R103 v3.0: Pass si <1%, Warning si <2%. Útil para validar una entrega contra el estándar sin interpretación."),
                ("Permisivo OTT (Netflix, Amazon…)",
                 "Muy laxo. Pass si <5%, Warning si <1%. Conviene a entregas OTT que se transcodifican después a múltiples objetivos."),
            ]),
            .h2("Pestaña Licencia"),
            .p("Estado de la licencia en la parte superior (prueba / licencia de por vida / expirada), campo de entrada de clave en monoespacio, contador 40/40, botones Activar, Comprar una licencia (abre Payhip) y Desactivar la licencia (visible solo cuando una licencia está activa)."),
            .h2("Pestaña Acerca de"),
            .p("Logo de MisiQC Pro, nombre de la aplicación, breve descripción del valor añadido, enlace a www.misiraca.com, versión del software."),
        ]),
        ManualSection(number: 7,
                      title: "Exportaciones: PDF, guía de corrección, CSV",
                      elements: [
            .h2("Exportación PDF del informe"),
            .p("El PDF del informe está diseñado para ser archivado, transmitido al difusor o adjuntado a un correo de entrega. Formato A4 vertical, generado mediante PDFKit nativo."),
            .bullets([
                "Página de portada: nombre del archivo, perfil de canal (con versión de la especificación), fecha de análisis, veredicto general con contadores Pass/Warning/Fail.",
                "Metadatos del archivo: duración, tamaño, framerate detectado, códec, etc.",
                "Tabla por categoría: Contenedor, Vídeo, Audio, Loudness, Estructura, Contenido, con etiqueta / valor esperado / valor medido / estado.",
                "Página apaisada opcional: línea de tiempo signal range (curva sobre la duración del programa) si se ha muestreado la serie temporal.",
                "Pie de página: versión de la app, versión del perfil, marca de agua de trazabilidad.",
            ]),
            .h2("Marca de agua"),
            .keyValueTable([
                ("Período de prueba", "« INFORME GENERADO EN MODO PRUEBA » en pie de página (gris discreto)."),
                ("Licencia activa",   "« Licencia: XXXXX · Host: Nombre-del-Mac » — 5 primeros caracteres de la clave + nombre de la máquina. Permite rastrear un uso no autorizado."),
                ("Prueba expirada",   "El PDF no se puede exportar mientras la prueba esté expirada y no se haya activado licencia."),
            ]),
            .h2("Guía de corrección (Remediation Guide)"),
            .p("La guía de corrección es un PDF complementario generado bajo demanda. Solo contiene los controles fallidos (estado Fail) con, para cada uno, recetas de corrección concretas."),
            .bullets([
                "Página de portada: resumen del archivo fuente, número de problemas a corregir, advertencia de responsabilidad.",
                "Una ficha por fallo: etiqueta del control, causa técnica, recetas de corrección por software.",
                "Recetas ffmpeg (línea de comandos exacta para ejecutar en terminal).",
                "Recetas DaVinci Resolve (menú Color Science, Project Settings, Deliver tab).",
                "Recetas Adobe Premiere Pro (paneles Effects, Lumetri Color, Audio Mixer, Export Media).",
                "Recetas Avid Media Composer (módulos de exportación, settings PCM, Source Settings).",
                "Enlaces a la documentación oficial del difusor y del software cuando proceda.",
            ]),
            .card(title: "¿Cuándo usar la guía de corrección?",
                  body: "Cuando tu informe principal contiene uno o varios fallos, exporta la guía de corrección y transmítela al colorista / mezclador / editor. Podrá aplicar la receta para el software que utiliza sin tener que interpretar el pliego del difusor.",
                  accent: accentBlue),
            .h2("Exportación CSV"),
            .p("El CSV está destinado a flujos con hojas de cálculo (Excel, Numbers, Google Sheets) o scripts (pandas, R). Tres bloques:"),
            .bullets([
                "Bloque 1 — Metadatos: Archivo, Perfil, Fecha de análisis, Veredicto, contadores Pass/Warning/Fail.",
                "Bloque 2 — Tabla de controles: columnas Categoría, Etiqueta, Esperado, Medido, Estado, Detalle.",
                "Bloque 3 (opcional) — Serie temporal signalstats muestreada cada N frames: pts_sec, YAVG, YMIN, YMAX, BRNG, TOUT, VREP. Importable directamente en pandas para graficar la línea de tiempo.",
            ]),
        ]),
        ManualSection(number: 8,
                      title: "Licencia, actualizaciones y soporte",
                      elements: [
            .h2("Licencia de por vida"),
            .bullets([
                "Una sola clave es suficiente, válida de por vida, en todos tus Macs personales.",
                "Sin limitación de hardware, sin llamada al servidor para validación: 100 % offline.",
                "Las actualizaciones mayores están incluidas en la licencia de por vida.",
                "Puedes transferir tu licencia desactivándola en un Mac (Ajustes → Licencia → Desactivar) y luego reactivándola en otro.",
            ]),
            .h2("Actualizaciones automáticas (Sparkle)"),
            .bullets([
                "MisiQC Pro integra Sparkle 2.x, el framework estándar de actualización para aplicaciones macOS fuera de la Mac App Store.",
                "En cada inicio, la app comprueba en segundo plano si hay una nueva versión disponible.",
                "Puedes forzar la comprobación desde el menú MisiQC Pro → Buscar actualizaciones…",
                "Las actualizaciones están firmadas con una clave Ed25519 dedicada. Una actualización no firmada por mi Mac es rechazada por Sparkle — ningún riesgo de actualización falsa maliciosa.",
                "La actualización se aplica al reiniciar la app, sin perder tu licencia ni tus preferencias.",
            ]),
            .h2("Soporte y contacto"),
            .keyValueTable([
                ("Email",            "contact@misiraca.com — respuesta en 48 h en días laborables."),
                ("Sitio",            "www.misiraca.com — novedades y notas de versión."),
                ("Reporte de bugs",  "Indica: versión de la app (Menú MisiQC Pro → Acerca de), versión de macOS, descripción del problema, y a ser posible una muestra de vídeo (≤30 s) que reproduzca el bug."),
                ("Sugerencias",      "Bienvenidas — indica el contexto broadcast (canal, tipo de programa) para ayudar a priorizar."),
            ]),
            .h2("Preguntas frecuentes"),
            .card(title: "El análisis es muy lento en un programa largo — ¿es normal?",
                  body: "Sí, la duración del análisis es proporcional a la del programa. Para 1 h 30 cuenta ~10 minutos. La app pasa la totalidad del archivo por varios filtros ffmpeg (ebur128, signalstats, mpdecimate, etc.) — es inherente a la profundidad de los controles.",
                  accent: accentBlue),
            .card(title: "Mi archivo MXF falla en el control « shim » aunque los valores de vídeo parezcan correctos.",
                  body: "El shim (AS-10 HIGH_HD_2014, RDD9, etc.) es una etiqueta portada por los metadatos del contenedor MXF. Si tu encoder no especifica el shim, se marcará como faltante aunque todo lo demás sea conforme. Solución: re-codificar con una cadena que establezca el shim explícitamente, o usar un re-wrapper MXF dedicado.",
                  accent: accentPeach),
            .card(title: "El control loudness muestra -22,7 LUFS para un objetivo -23 ± 1. ¿Por qué es Pass y no Warning?",
                  body: "Porque -22,7 LUFS está dentro de la ventana de tolerancia (-24 a -22 LUFS). El control pasa a Warning cerca de los límites (por ejemplo -22,0 o -23,95) y a Fail más allá. La zona Warning se define por cada perfil de canal.",
                  accent: accentBlue),
            .card(title: "¿Puedo analizar un archivo directamente desde un disco de red?",
                  body: "Sí, siempre que macOS haya montado el recurso compartido (SMB, AFP, NFS). MisiQC Pro accede al archivo en solo lectura mediante las API estándar de Foundation. Si la red es lenta, el análisis será proporcionalmente más largo.",
                  accent: accentBlue),
            .card(title: "¿Y si pierdo mi clave?",
                  body: "Sin pánico: tu compra Payhip está vinculada a tu correo. Escribe a contact@misiraca.com indicando el correo de tu compra y te reenviaré tu clave.",
                  accent: accentMint),
            .h2("Condiciones de licencia"),
            .bullets([
                "✅ Uso personal y profesional ilimitado en tus Macs.",
                "✅ Generación ilimitada de informes PDF / CSV / guía de corrección.",
                "✅ Actualizaciones menores y mayores incluidas de por vida.",
                "❌ Reventa, distribución o compartición de la clave prohibidas.",
                "❌ Ingeniería inversa, desensamblaje o elusión del control de licencia prohibidos.",
                "La compartición no autorizada de una clave puede rastrearse mediante las marcas de agua de los informes PDF generados.",
            ]),
            .h2("Créditos"),
            .p("MisiQC Pro está diseñado y desarrollado por Matthieu Misiraca en París. La aplicación se apoya en ffmpeg y ffprobe (LGPL), Sparkle 2.x (BSD) y el ecosistema SwiftUI / CryptoKit de Apple."),
            .spacer(8),
            .card(title: "Gracias por tu confianza",
                  body: "¡Y feliz control de calidad! No dudes en escribirme con cualquier pregunta, sugerencia o comentario de producción.\n— Matthieu",
                  accent: accentViolet),
        ]),
    ]
)

// MARK: - Render all 3 languages

func renderLanguage(_ lang: Lang) {
    let s: LangStrings
    switch lang {
    case .fr: s = strFR
    case .en: s = strEN
    case .es: s = strES
    }
    drawCoverPage(lang: lang, strings: s)
    for section in s.sections {
        renderSection(section, strings: s, lang: lang)
    }
}

for lang in Lang.allCases { renderLanguage(lang) }

ctx.closePDF()
try (data as Data).write(to: pdfURL)
print("✅ \(pdfURL.lastPathComponent) generated (\(totalPageCount) pages) at \(pdfURL.path)")
