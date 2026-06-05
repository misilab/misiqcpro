#!/usr/bin/env swift
// MisiQC Pro — Customer Welcome PDF renderer
// ---------------------------------------------------------------------------
// Generates a branded "Guide d'installation" PDF that customers receive with
// their licence key after purchasing on Payhip. Uses the same logo + colours
// as the in-app reports so the touch point feels consistent.
//
// Usage:
//   swift scripts/render_customer_pdf.swift
//
// Output:
//   scripts/output/MisiQC-Pro-Guide-Installation.pdf

import Foundation
import AppKit

let projectRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent()
let outputDir = projectRoot.appendingPathComponent("scripts/output")
try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
let pdfURL = outputDir.appendingPathComponent("MisiQC-Pro-Guide-Installation.pdf")

// MARK: - Brand colours (mirrors DesignSystem/BrandPalette.swift)

let gradientStart = NSColor(calibratedRed: 0.157, green: 0.788, blue: 1.000, alpha: 1)
let gradientMid   = NSColor(calibratedRed: 0.404, green: 0.298, blue: 1.000, alpha: 1)
let gradientEnd   = NSColor(calibratedRed: 1.000, green: 0.224, blue: 0.494, alpha: 1)
let accentBlue    = NSColor(calibratedRed: 0.180, green: 0.475, blue: 0.960, alpha: 1)
let accentMint    = NSColor(calibratedRed: 0.118, green: 0.682, blue: 0.408, alpha: 1)
let accentPeach   = NSColor(calibratedRed: 0.937, green: 0.510, blue: 0.114, alpha: 1)
let primaryText   = NSColor(calibratedWhite: 0.15, alpha: 1)
let secondaryText = NSColor(calibratedWhite: 0.45, alpha: 1)
let mutedBG       = NSColor(calibratedWhite: 0.97, alpha: 1)
let mutedBorder   = NSColor(calibratedWhite: 0.85, alpha: 1)

// A4 portrait at 72 dpi.
let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
let margin: CGFloat = 48

// MARK: - PDF context setup

let data = NSMutableData()
guard let consumer = CGDataConsumer(data: data) else { exit(1) }
var mediaBox = pageRect
guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { exit(1) }
let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)

// MARK: - Drawing helpers

func drawString(_ s: String, at point: CGPoint, font: NSFont,
                color: NSColor = primaryText, maxWidth: CGFloat? = nil) {
    if let maxWidth {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byWordWrapping
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: color, .paragraphStyle: style
        ]
        let rect = CGRect(x: point.x, y: point.y, width: maxWidth, height: 2000)
        (s as NSString).draw(in: rect, withAttributes: attrs)
    } else {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        (s as NSString).draw(at: point, withAttributes: attrs)
    }
}

func drawDownward(_ s: String, x: CGFloat, topY: CGFloat, width: CGFloat,
                  font: NSFont, color: NSColor, lineHeight: CGFloat) -> CGFloat {
    let style = NSMutableParagraphStyle()
    style.lineBreakMode = .byWordWrapping
    style.minimumLineHeight = lineHeight
    style.maximumLineHeight = lineHeight
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font, .foregroundColor: color, .paragraphStyle: style
    ]
    let bounds = (s as NSString).boundingRect(
        with: CGSize(width: width, height: 5000),
        options: [.usesLineFragmentOrigin, .usesFontLeading],
        attributes: attrs
    )
    let height = ceil(bounds.height) + 2
    let rect = CGRect(x: x, y: topY - height, width: width, height: height)
    (s as NSString).draw(in: rect, withAttributes: attrs)
    return height
}

// MARK: - Brand logo (mirrors DesignSystem/BrandLogo.swift)

func drawBrandLogo(in rect: CGRect) {
    let pixelSize = max(64, Int(rect.width * 4))
    let image = brandLogoImage(pixelSize: pixelSize)
    image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
}

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
    let colorspace = CGColorSpaceCreateDeviceRGB()
    let colors = [
        CGColor(red: 0.157, green: 0.788, blue: 1.0, alpha: 1),
        CGColor(red: 0.404, green: 0.298, blue: 1.0, alpha: 1),
        CGColor(red: 1.0,   green: 0.224, blue: 0.494, alpha: 1)
    ] as CFArray
    let gradient = CGGradient(colorsSpace: colorspace, colors: colors,
                              locations: [0, 0.55, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size),
                           end: CGPoint(x: size, y: 0), options: [])
    let hl = CGGradient(colorsSpace: colorspace, colors: [
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.4),
        CGColor(red: 1, green: 1, blue: 1, alpha: 0)
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(hl, start: CGPoint(x: 0, y: size),
                           end: CGPoint(x: 0, y: size * 0.5), options: [])
    ctx.restoreGState()
    let lineWidth = size * 0.105
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.setLineWidth(lineWidth)
    ctx.setLineCap(.round); ctx.setLineJoin(.round)
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
    let image = NSImage(size: NSSize(width: size, height: size))
    image.addRepresentation(bitmap)
    return image
}

// MARK: - Page elements

func drawCoverHeader(startY: CGFloat) -> CGFloat {
    let bandHeight: CGFloat = 200
    let bandRect = CGRect(x: 0, y: pageRect.height - bandHeight,
                          width: pageRect.width, height: bandHeight)
    let cs = CGColorSpaceCreateDeviceRGB()
    let grad = CGGradient(colorsSpace: cs, colors: [
        gradientStart.cgColor, gradientMid.cgColor, gradientEnd.cgColor
    ] as CFArray, locations: [0, 0.55, 1])!
    ctx.saveGState()
    ctx.addRect(bandRect); ctx.clip()
    ctx.drawLinearGradient(grad,
                           start: CGPoint(x: 0, y: bandRect.maxY),
                           end: CGPoint(x: bandRect.width, y: bandRect.minY),
                           options: [])
    ctx.restoreGState()

    let logoSize: CGFloat = 84
    let logoY = bandRect.maxY - 30 - logoSize
    drawBrandLogo(in: CGRect(x: margin, y: logoY, width: logoSize, height: logoSize))

    drawString("MisiQC Pro",
               at: CGPoint(x: margin + logoSize + 18,
                           y: logoY + logoSize - 38),
               font: .systemFont(ofSize: 30, weight: .heavy),
               color: .white)
    drawString("Guide d'installation & activation de licence",
               at: CGPoint(x: margin + logoSize + 18,
                           y: logoY + logoSize - 62),
               font: .systemFont(ofSize: 12.5, weight: .medium),
               color: NSColor(calibratedWhite: 1, alpha: 0.85))

    drawString("Bienvenue 🎬 — vous voilà équipé du contrôle qualité PAD.",
               at: CGPoint(x: margin, y: bandRect.minY + 20),
               font: .systemFont(ofSize: 11, weight: .medium),
               color: NSColor(calibratedWhite: 1, alpha: 0.85))
    return bandRect.minY - 28
}

func drawSectionHeader(_ title: String, number: Int, at y: CGFloat) -> CGFloat {
    let chipSize: CGFloat = 22
    let chipRect = CGRect(x: margin, y: y - chipSize, width: chipSize, height: chipSize)
    accentBlue.setFill()
    NSBezierPath(ovalIn: chipRect).fill()
    drawString("\(number)",
               at: CGPoint(x: chipRect.midX - 4, y: chipRect.midY - 7),
               font: .systemFont(ofSize: 12, weight: .heavy),
               color: .white)
    drawString(title,
               at: CGPoint(x: chipRect.maxX + 10, y: y - 18),
               font: .systemFont(ofSize: 15, weight: .heavy),
               color: primaryText)
    return y - 30
}

/// Draws an info card with a soft background, returns the new y cursor.
func drawCard(title: String?, body: String, atTopY y: CGFloat,
              accent: NSColor = accentBlue) -> CGFloat {
    let innerWidth = pageRect.width - margin * 2 - 24
    var bodyHeight = stringHeight(body, font: .systemFont(ofSize: 10.5),
                                  width: innerWidth, lineHeight: 14)
    var titleHeight: CGFloat = 0
    if title != nil { titleHeight = 18 }
    let pad: CGFloat = 14
    let totalHeight = titleHeight + bodyHeight + pad * 2
    let rect = CGRect(x: margin, y: y - totalHeight,
                      width: pageRect.width - margin * 2, height: totalHeight)
    mutedBG.setFill()
    NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).fill()
    mutedBorder.setStroke()
    let border = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
    border.lineWidth = 0.5
    border.stroke()
    // Accent stripe on the left.
    accent.withAlphaComponent(0.9).setFill()
    NSBezierPath(rect: CGRect(x: rect.minX, y: rect.minY,
                              width: 3, height: rect.height)).fill()

    var cursorY = rect.maxY - pad
    if let title {
        drawString(title,
                   at: CGPoint(x: rect.minX + pad + 6, y: cursorY - 12),
                   font: .systemFont(ofSize: 11, weight: .heavy),
                   color: accent)
        cursorY -= titleHeight
    }
    bodyHeight = drawDownward(body, x: rect.minX + pad + 6, topY: cursorY,
                              width: innerWidth - 6,
                              font: .systemFont(ofSize: 10.5),
                              color: primaryText, lineHeight: 14)
    _ = bodyHeight
    return rect.minY - 14
}

func stringHeight(_ s: String, font: NSFont, width: CGFloat,
                  lineHeight: CGFloat) -> CGFloat {
    let style = NSMutableParagraphStyle()
    style.lineBreakMode = .byWordWrapping
    style.minimumLineHeight = lineHeight
    style.maximumLineHeight = lineHeight
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .paragraphStyle: style]
    return ceil((s as NSString).boundingRect(
        with: CGSize(width: width, height: 5000),
        options: [.usesLineFragmentOrigin, .usesFontLeading],
        attributes: attrs).height) + 2
}

func drawBullet(_ text: String, atTopY y: CGFloat) -> CGFloat {
    let bx = margin + 32
    let bullet = "•"
    drawString(bullet, at: CGPoint(x: bx, y: y - 12),
               font: .systemFont(ofSize: 11, weight: .bold), color: accentBlue)
    let h = drawDownward(text, x: bx + 12, topY: y,
                         width: pageRect.width - bx - 12 - margin,
                         font: .systemFont(ofSize: 10.5),
                         color: primaryText, lineHeight: 14)
    return y - h - 4
}

// MARK: - Build the pages

func startNewPage() -> CGFloat {
    ctx.beginPDFPage(nil)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsCtx
    return pageRect.height
}

func endPage(footerNumber: Int) {
    let appVersion = "1.0"
    let footer = "MisiQC Pro v\(appVersion) · Guide d'installation · contact@misiraca.com · Page \(footerNumber)"
    let f = NSFont.systemFont(ofSize: 8, weight: .medium)
    let w = (footer as NSString).size(withAttributes: [.font: f]).width
    drawString(footer,
               at: CGPoint(x: (pageRect.width - w) / 2, y: 18),
               font: f, color: secondaryText)
    NSColor(calibratedWhite: 0.88, alpha: 1).setStroke()
    let sep = NSBezierPath()
    sep.move(to: CGPoint(x: margin, y: 36))
    sep.line(to: CGPoint(x: pageRect.width - margin, y: 36))
    sep.lineWidth = 0.4
    sep.stroke()
    NSGraphicsContext.restoreGraphicsState()
    ctx.endPDFPage()
}

// ===== Page 1 =====
var y = startNewPage()
y = drawCoverHeader(startY: y)

y = drawSectionHeader("Installation de MisiQC Pro", number: 1, at: y)
y = drawCard(title: "Étape 1 — Télécharger l'application",
             body: "Le lien de téléchargement de MisiQC-Pro.zip se trouve dans l'email de confirmation Payhip que vous venez de recevoir.",
             atTopY: y, accent: accentBlue)
y = drawCard(title: "Étape 2 — Déplacer dans Applications",
             body: "Double-cliquez sur le .zip pour le décompresser, puis glissez MisiQC Pro.app dans le dossier Applications de votre Mac.",
             atTopY: y, accent: accentBlue)
y = drawCard(title: "Étape 3 — Premier lancement",
             body: "macOS affichera une alerte de sécurité au premier lancement. Dans le Finder → Applications, faites clic droit sur MisiQC Pro → Ouvrir, puis cliquez à nouveau sur Ouvrir dans la boîte de dialogue. Cette étape est nécessaire une seule fois.",
             atTopY: y, accent: accentPeach)

endPage(footerNumber: 1)

// ===== Page 2 =====
y = startNewPage()
y -= margin
y = drawSectionHeader("Activer votre licence à vie 🔑", number: 2, at: y)

y = drawCard(title: nil,
             body: "Votre clé de licence vous a été envoyée par email après votre achat sur Payhip. Elle ressemble à : XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-…-XXXXX",
             atTopY: y, accent: accentMint)

let activationSteps = [
    "Lancez MisiQC Pro.",
    "Menu MisiQC Pro → Réglages… (ou ⌘ ,).",
    "Cliquez sur l'onglet 🔑 Licence.",
    "Collez votre clé dans le champ « Clé reçue par email ».",
    "Cliquez sur Activer."
]
for step in activationSteps {
    y = drawBullet(step, atTopY: y)
}
y -= 8
y = drawCard(title: "Résultat attendu",
             body: "✅ « Merci ! Licence valide à vie. » Le bandeau d'essai disparaît automatiquement et tous les exports (PDF rapport, CSV, guide de correction) sont débloqués.",
             atTopY: y, accent: accentMint)

y = drawSectionHeader("Important à savoir", number: 3, at: y)
let knowing = [
    "Licence à vie — votre clé n'expire jamais. Les mises à jour majeures sont incluses.",
    "Multi-Mac — la clé est valable sur tous vos Macs personnels.",
    "Stockage sécurisé — la clé est conservée dans votre Trousseau macOS.",
    "Traçabilité — le nom de votre Mac + les 5 premiers caractères de votre clé apparaissent discrètement en pied de page des rapports PDF, pour décourager le partage non autorisé."
]
for k in knowing { y = drawBullet(k, atTopY: y) }

endPage(footerNumber: 2)

// ===== Page 3 =====
y = startNewPage()
y -= margin

y = drawSectionHeader("Mises à jour & support", number: 4, at: y)
y = drawCard(title: "Mises à jour automatiques",
             body: "MisiQC Pro vérifie automatiquement les mises à jour au lancement. Vous pouvez aussi forcer la vérification via le menu MisiQC Pro → Vérifier les mises à jour…",
             atTopY: y, accent: accentBlue)
y = drawCard(title: "Support",
             body: "Une question, un bug, une demande de fonctionnalité ?\nContact : contact@misiraca.com — Site : www.misiraca.com\n\nPour les bugs : précisez la version (Menu MisiQC Pro → À propos), votre version de macOS, une description et idéalement un fichier exemple.",
             atTopY: y, accent: accentBlue)

y = drawSectionHeader("Conditions de licence", number: 5, at: y)
let terms = [
    "✅ Usage personnel et professionnel illimité sur vos Macs.",
    "✅ Génération de rapports PDF / CSV illimitée.",
    "✅ Mises à jour gratuites à vie.",
    "❌ Revente, partage ou distribution de la clé interdits.",
    "❌ Reverse-engineering interdit.",
    "Le partage non autorisé d'une clé peut être tracé via les rapports PDF générés."
]
for t in terms { y = drawBullet(t, atTopY: y) }

// Sign-off
y -= 24
drawString("Merci pour votre confiance, et bons contrôles qualité !",
           at: CGPoint(x: margin, y: y - 14),
           font: .systemFont(ofSize: 13, weight: .heavy),
           color: primaryText)
drawString("— Matthieu Misiraca, développeur de MisiQC Pro",
           at: CGPoint(x: margin, y: y - 32),
           font: .systemFont(ofSize: 11, weight: .medium),
           color: secondaryText)

endPage(footerNumber: 3)

ctx.closePDF()
try (data as Data).write(to: pdfURL)
print("✅ \(pdfURL.lastPathComponent) generated at \(pdfURL.path)")
