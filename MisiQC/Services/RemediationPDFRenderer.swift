import Foundation
import AppKit
import PDFKit

/// Renders a remediation guide PDF: one card per failing check with cause and
/// per-software fix recipes (DaVinci Resolve, Premiere, Avid, FFmpeg…).
enum RemediationPDFRenderer {

    enum RenderError: LocalizedError {
        case writeFailed(String)
        case nothingToFix(AppLocale)
        var errorDescription: String? {
            switch self {
            case .writeFailed(let m): return m
            case .nothingToFix(let l): return L10n.t(.remedNothingToFix, l)
            }
        }
    }

    static func write(_ report: QCReport, to destination: URL) throws {
        let guides = RemediationCatalog.guides(for: report)
        guard !guides.isEmpty else { throw RenderError.nothingToFix(report.locale) }
        let data = render(report: report, guides: guides)
        do { try data.write(to: destination, options: .atomic) }
        catch { throw RenderError.writeFailed(error.localizedDescription) }
    }

    private static func render(report: QCReport,
                               guides: [(Check, LocalizedRemediationGuide)]) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data) else { return Data() }
        var mediaBox = pageRect
        guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return Data() }
        let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)

        let margin: CGFloat = 36
        var pageIdx = 0
        var totalPagesEstimate = 1
        // Cheap pre-pass to estimate page count for the page-N/M footer.
        totalPagesEstimate = estimatePageCount(guides: guides, pageRect: pageRect, margin: margin)

        // First page: cover.
        ctx.beginPDFPage(nil)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsCtx
        var cursor = pageRect.height - margin
        cursor = drawCover(report: report, guideCount: guides.count,
                           in: pageRect, margin: margin, startY: cursor)
        drawFooter(report: report, pageIndex: pageIdx,
                   totalPages: totalPagesEstimate,
                   pageRect: pageRect, margin: margin)
        NSGraphicsContext.restoreGraphicsState()
        ctx.endPDFPage()
        pageIdx += 1

        // Body pages: stream the guides until they fill the page, then break.
        var inFlightCards: [(Check, LocalizedRemediationGuide)] = guides
        while !inFlightCards.isEmpty {
            ctx.beginPDFPage(nil)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = nsCtx
            cursor = pageRect.height - margin
            cursor = drawPageHeader(report: report, in: pageRect,
                                    margin: margin, startY: cursor)
            cursor -= 8

            while let (check, guide) = inFlightCards.first {
                let height = measureCardHeight(check: check, guide: guide,
                                               width: pageRect.width - margin * 2)
                if cursor - height < 60 {
                    break  // out of room on this page, leave card for next page
                }
                drawCard(check: check, guide: guide,
                         in: pageRect, margin: margin, startY: cursor, height: height,
                         locale: report.locale)
                cursor -= (height + 14)
                inFlightCards.removeFirst()
            }

            drawFooter(report: report, pageIndex: pageIdx,
                       totalPages: totalPagesEstimate,
                       pageRect: pageRect, margin: margin)
            NSGraphicsContext.restoreGraphicsState()
            ctx.endPDFPage()
            pageIdx += 1
        }

        ctx.closePDF()
        return data as Data
    }

    private static func estimatePageCount(guides: [(Check, LocalizedRemediationGuide)],
                                          pageRect: CGRect, margin: CGFloat) -> Int {
        let usableHeight = pageRect.height - margin * 2 - 80
        var remaining = usableHeight
        var pages = 1 // body page 1
        for (check, guide) in guides {
            let h = measureCardHeight(check: check, guide: guide,
                                      width: pageRect.width - margin * 2)
            if remaining - h < 60 {
                pages += 1
                remaining = usableHeight
            }
            remaining -= (h + 14)
        }
        return pages + 1 // + cover
    }

    // MARK: - Cover

    private static func drawCover(report: QCReport, guideCount: Int,
                                  in pageRect: CGRect, margin: CGFloat,
                                  startY: CGFloat) -> CGFloat {
        let locale = report.locale
        var y = startY
        drawBrandLogo(in: CGRect(x: margin, y: y - 56, width: 56, height: 56))
        drawString(L10n.t(.remedPDFTitle, locale),
                   at: CGPoint(x: margin + 70, y: y - 30),
                   font: .systemFont(ofSize: 22, weight: .heavy))
        drawString(L10n.t(.remedPDFSubtitle, locale),
                   at: CGPoint(x: margin + 70, y: y - 50),
                   font: .systemFont(ofSize: 11, weight: .medium),
                   color: NSColor(white: 0.35, alpha: 1))
        y -= 80

        let info: [(String, String)] = [
            (L10n.t(.remedFile, locale), report.fileURL.lastPathComponent),
            (L10n.t(.remedProfile, locale), report.spec.name + " — " + report.spec.specVersion),
            (L10n.t(.remedToFix, locale), "\(guideCount)")
        ]
        let rowH: CGFloat = 22
        let infoH = CGFloat(info.count) * rowH + 14
        let infoRect = CGRect(x: margin, y: y - infoH,
                              width: pageRect.width - margin * 2, height: infoH)
        NSColor(white: 0.97, alpha: 1).setFill()
        NSBezierPath(roundedRect: infoRect, xRadius: 8, yRadius: 8).fill()
        NSColor(white: 0.85, alpha: 1).setStroke()
        let border = NSBezierPath(roundedRect: infoRect, xRadius: 8, yRadius: 8)
        border.lineWidth = 0.5
        border.stroke()
        for (i, (label, value)) in info.enumerated() {
            // baseline of each line, growing downward from top.
            let lineBaseline = infoRect.maxY - 18 - CGFloat(i) * rowH
            drawString(label.uppercased(),
                       at: CGPoint(x: infoRect.minX + 14, y: lineBaseline),
                       font: .systemFont(ofSize: 9, weight: .bold),
                       color: NSColor(white: 0.45, alpha: 1))
            drawString(value,
                       at: CGPoint(x: infoRect.minX + 180, y: lineBaseline),
                       font: .systemFont(ofSize: 10.5, weight: .medium),
                       maxWidth: infoRect.width - 190)
        }
        y = infoRect.minY - 28

        drawString(L10n.t(.remedHowToUseTitle, locale),
                   at: CGPoint(x: margin, y: y - 14),
                   font: .systemFont(ofSize: 13, weight: .heavy),
                   color: accentBlue)
        y -= 24

        let introHeight = drawDownward(L10n.t(.remedHowToUseBody, locale),
                                       x: margin, topY: y,
                                       width: pageRect.width - margin * 2,
                                       font: .systemFont(ofSize: 10.5),
                                       color: NSColor(white: 0.25, alpha: 1),
                                       lineHeight: 15)
        y -= introHeight + 12
        return y
    }

    private static func drawPageHeader(report: QCReport, in pageRect: CGRect,
                                       margin: CGFloat, startY: CGFloat) -> CGFloat {
        let y = startY
        drawBrandLogo(in: CGRect(x: margin, y: y - 22, width: 22, height: 22))
        drawString(L10n.t(.remedPageHeader, report.locale),
                   at: CGPoint(x: margin + 30, y: y - 16),
                   font: .systemFont(ofSize: 12, weight: .semibold))
        let right = report.spec.name + " · " + report.spec.specVersion
        let rfont = NSFont.systemFont(ofSize: 10, weight: .medium)
        let rw = (right as NSString).size(withAttributes: [.font: rfont]).width
        drawString(right,
                   at: CGPoint(x: pageRect.width - margin - rw, y: y - 16),
                   font: rfont, color: NSColor(white: 0.45, alpha: 1))
        return y - 32
    }

    // MARK: - Card

    private static let cardPad: CGFloat = 14
    private static let titleBlockH: CGFloat = 38
    private static let softwareHeaderH: CGFloat = 18
    private static let stepGap: CGFloat = 3
    private static let actionGap: CGFloat = 10
    private static let causeLine: CGFloat = 14
    private static let stepLine: CGFloat = 13

    private static func measureCardHeight(check: Check, guide: LocalizedRemediationGuide,
                                          width: CGFloat) -> CGFloat {
        let innerWidth = width - cardPad * 2
        let stepIndent: CGFloat = 18
        var h = cardPad + titleBlockH
        h += measuredWrappedHeight(guide.cause,
                                   font: .systemFont(ofSize: 10),
                                   width: innerWidth,
                                   lineHeight: causeLine)
        h += 10
        for action in guide.actions {
            h += softwareHeaderH
            for step in action.steps {
                h += measuredWrappedHeight("•  " + step,
                                           font: .systemFont(ofSize: 9.5),
                                           width: innerWidth - stepIndent,
                                           lineHeight: stepLine) + stepGap
            }
            h += actionGap
        }
        return h + cardPad
    }

    private static func drawCard(check: Check, guide: LocalizedRemediationGuide,
                                 in pageRect: CGRect, margin: CGFloat,
                                 startY: CGFloat, height: CGFloat, locale: AppLocale) {
        let cardRect = CGRect(x: margin, y: startY - height,
                              width: pageRect.width - margin * 2, height: height)
        let accent = statusColor(check.status)

        accent.withAlphaComponent(0.06).setFill()
        NSBezierPath(roundedRect: cardRect, xRadius: 10, yRadius: 10).fill()
        accent.withAlphaComponent(0.28).setStroke()
        let border = NSBezierPath(roundedRect: cardRect, xRadius: 10, yRadius: 10)
        border.lineWidth = 0.6
        border.stroke()

        let innerX = cardRect.minX + cardPad
        let innerWidth = cardRect.width - cardPad * 2
        var y = cardRect.maxY - cardPad

        // Pip + check label.
        let pip = CGRect(x: innerX, y: y - 12, width: 9, height: 9)
        accent.setFill()
        NSBezierPath(ovalIn: pip).fill()
        drawString(check.label,
                   at: CGPoint(x: pip.maxX + 8, y: y - 12),
                   font: .systemFont(ofSize: 9.5, weight: .heavy),
                   color: NSColor(white: 0.45, alpha: 1),
                   maxWidth: innerWidth - 22)
        y -= 18

        // Remediation title.
        drawString(guide.title,
                   at: CGPoint(x: innerX, y: y - 14),
                   font: .systemFont(ofSize: 13, weight: .heavy),
                   color: accent,
                   maxWidth: innerWidth)
        y -= 22

        // Cause paragraph (drawn downward).
        let causeH = drawDownward(guide.cause,
                                  x: innerX, topY: y,
                                  width: innerWidth,
                                  font: .systemFont(ofSize: 10),
                                  color: NSColor(white: 0.25, alpha: 1),
                                  lineHeight: causeLine)
        y -= (causeH + 8)

        // Per-software fixes.
        let stepIndent: CGFloat = 18
        for action in guide.actions {
            drawString(action.software.uppercased(),
                       at: CGPoint(x: innerX, y: y - 12),
                       font: .systemFont(ofSize: 9, weight: .heavy),
                       color: accentBlue)
            y -= softwareHeaderH

            for step in action.steps {
                let bullet = "•  " + step
                let stepH = drawDownward(bullet,
                                         x: innerX + stepIndent, topY: y,
                                         width: innerWidth - stepIndent,
                                         font: .systemFont(ofSize: 9.5),
                                         color: NSColor(white: 0.2, alpha: 1),
                                         lineHeight: stepLine)
                y -= (stepH + stepGap)
            }
            y -= actionGap
        }
    }

    // MARK: - Footer

    private static func drawFooter(report: QCReport, pageIndex: Int, totalPages: Int,
                                   pageRect: CGRect, margin: CGFloat) {
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let runningLabel = L10n.t(.remedRunningFooter, report.locale)
        let topLine = "MisiQC Pro v\(appVersion) · \(runningLabel) · Page \(pageIndex + 1)/\(totalPages)"
        drawString(topLine,
                   at: CGPoint(x: margin, y: 26),
                   font: .systemFont(ofSize: 8),
                   color: NSColor(white: 0.55, alpha: 1))
        let signature = "Guide généré par MisiQC Pro — Conçu par Matthieu Misiraca · www.misiraca.com"
        let sigFont = NSFont.systemFont(ofSize: 8, weight: .medium)
        let sigW = (signature as NSString).size(withAttributes: [.font: sigFont]).width
        drawString(signature,
                   at: CGPoint(x: (pageRect.width - sigW) / 2, y: 14),
                   font: sigFont, color: NSColor(white: 0.45, alpha: 1))
        NSColor(white: 0.88, alpha: 1).setStroke()
        let sep = NSBezierPath()
        sep.move(to: CGPoint(x: margin, y: 38))
        sep.line(to: CGPoint(x: pageRect.width - margin, y: 38))
        sep.lineWidth = 0.4
        sep.stroke()
    }

    // MARK: - String helpers

    private static func drawString(_ s: String, at point: CGPoint, font: NSFont,
                                   color: NSColor = .black, maxWidth: CGFloat? = nil) {
        if let maxWidth {
            let style = NSMutableParagraphStyle()
            style.lineBreakMode = .byTruncatingTail
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font, .foregroundColor: color, .paragraphStyle: style
            ]
            // In a non-flipped CG context, NSString.draw(in:) renders the line
            // at the TOP of the rect. We treat point.y as the desired text TOP,
            // so position rect.y = point.y - height (same fix applied earlier
            // to scripts/render_customer_pdf.swift).
            let h = font.pointSize + 4
            let rect = CGRect(x: point.x, y: point.y - h, width: maxWidth, height: h)
            (s as NSString).draw(in: rect, withAttributes: attrs)
        } else {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font, .foregroundColor: color
            ]
            (s as NSString).draw(at: point, withAttributes: attrs)
        }
    }

    /// Draws wrapped text downward from `topY`: the top of the first line is
    /// at `topY`, subsequent lines descend. Returns the total consumed height
    /// so the caller can advance its cursor (`y -= returned`).
    @discardableResult
    private static func drawDownward(_ s: String, x: CGFloat, topY: CGFloat,
                                     width: CGFloat, font: NSFont,
                                     color: NSColor, lineHeight: CGFloat) -> CGFloat {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byWordWrapping
        style.minimumLineHeight = lineHeight
        style.maximumLineHeight = lineHeight
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: color, .paragraphStyle: style
        ]
        let height = measuredWrappedHeight(s, font: font, width: width, lineHeight: lineHeight)
        // In CG-unflipped, draw(in:) renders text from the top of the rect
        // downward. So we place the rect so that its top edge sits at topY.
        let rect = CGRect(x: x, y: topY - height, width: width, height: height)
        (s as NSString).draw(in: rect, withAttributes: attrs)
        return height
    }

    private static func measuredWrappedHeight(_ s: String, font: NSFont,
                                              width: CGFloat, lineHeight: CGFloat) -> CGFloat {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byWordWrapping
        style.minimumLineHeight = lineHeight
        style.maximumLineHeight = lineHeight
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font, .paragraphStyle: style
        ]
        let bounds = (s as NSString).boundingRect(
            with: CGSize(width: width, height: 5000),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs
        )
        return ceil(bounds.height) + 2
    }

    // MARK: - Brand & color helpers (shared with main PDF)

    private static let accentBlue = NSColor(calibratedRed: 0.180, green: 0.475, blue: 0.960, alpha: 1)
    private static let accentMint = NSColor(calibratedRed: 0.118, green: 0.682, blue: 0.408, alpha: 1)
    private static let accentPeach = NSColor(calibratedRed: 0.937, green: 0.510, blue: 0.114, alpha: 1)
    private static let accentRed = NSColor(calibratedRed: 0.851, green: 0.196, blue: 0.196, alpha: 1)

    private static func statusColor(_ s: CheckStatus) -> NSColor {
        switch s {
        case .pass: return accentMint
        case .warning: return accentPeach
        case .fail: return accentRed
        }
    }

    private static func drawBrandLogo(in rect: CGRect) {
        let pixelSize = max(64, Int(rect.width * 4))
        let image = brandLogoImage(pixelSize: pixelSize)
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    private static func brandLogoImage(pixelSize: Int) -> NSImage {
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
        ctx.saveGState()
        ctx.addPath(bgPath); ctx.clip()
        let colorspace = CGColorSpaceCreateDeviceRGB()
        let colors = [
            CGColor(red: 0.176, green: 0.847, blue: 1.000, alpha: 1),
            CGColor(red: 0.443, green: 0.357, blue: 1.000, alpha: 1),
            CGColor(red: 1.000, green: 0.310, blue: 0.557, alpha: 1)
        ] as CFArray
        let gradient = CGGradient(colorsSpace: colorspace, colors: colors,
                                  locations: [0, 0.55, 1])!
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size),
                               end: CGPoint(x: size, y: 0), options: [])
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
}
