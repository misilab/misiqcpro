import Foundation
import AppKit
import PDFKit

/// Renders a `QCReport` to a polished A4 PDF: brand logo, verdict banner,
/// pastel stat strip, category sections, and a discreet author footer.
enum PDFReportRenderer {

    enum RenderError: LocalizedError {
        case writeFailed(String, AppLocale)
        var errorDescription: String? {
            switch self {
            case .writeFailed(let m, let l):
                return String(format: L10n.t(.errPDFWriteFailed, l), m)
            }
        }
    }

    static func write(_ report: QCReport, to destination: URL,
                      license: LicenseService? = nil) throws {
        currentLicenseWatermark = makeWatermark(license: license, locale: report.locale)
        defer { currentLicenseWatermark = nil }
        let data = render(report)
        do { try data.write(to: destination, options: .atomic) }
        catch { throw RenderError.writeFailed(error.localizedDescription, report.locale) }
    }

    /// Mutable per-render watermark — set by `write(_:to:license:)` before the
    /// rendering pass and consumed by `drawFooter`. Renderer is fundamentally
    /// stateless so a static slot is fine here.
    nonisolated(unsafe) private static var currentLicenseWatermark: String?

    @MainActor
    private static func makeWatermark(license: LicenseService?, locale: AppLocale) -> String {
        guard let license else { return L10n.t(.licenseWatermarkTrial, locale) }
        switch license.status {
        case .licensed(_, let fingerprint):
            return String(format: L10n.t(.licenseWatermark, locale),
                          fingerprint, license.hostName)
        case .trial:
            return L10n.t(.licenseWatermarkTrial, locale)
        case .expired:
            return L10n.t(.licenseWatermarkTrial, locale)
        }
    }

    static func render(_ report: QCReport) -> Data {
        // A4 portrait at 72 dpi.
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let landscapeRect = CGRect(x: 0, y: 0, width: 842, height: 595)
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data) else { return Data() }
        var mediaBox = pageRect
        guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return Data() }

        let pages = paginate(report: report, pageRect: pageRect)
        let hasTimeline = (report.content.timeSeries?.points.isEmpty == false)
        let totalPages = pages.count + (hasTimeline ? 1 : 0)
        let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)

        for (idx, page) in pages.enumerated() {
            ctx.beginPDFPage(nil)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = nsCtx
            drawPage(page, pageIndex: idx, totalPages: totalPages, in: pageRect, report: report)
            NSGraphicsContext.restoreGraphicsState()
            ctx.endPDFPage()
        }

        if hasTimeline, let series = report.content.timeSeries {
            var landscapeBox = landscapeRect
            let mediaBoxData = NSData(bytes: &landscapeBox,
                                      length: MemoryLayout<CGRect>.size)
            let landscapeInfo: [String: Any] = [
                kCGPDFContextMediaBox as String: mediaBoxData
            ]
            ctx.beginPDFPage(landscapeInfo as CFDictionary)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = nsCtx
            drawTimelinePage(report: report, series: series, in: landscapeRect,
                             pageIndex: pages.count, totalPages: totalPages)
            NSGraphicsContext.restoreGraphicsState()
            ctx.endPDFPage()
        }

        ctx.closePDF()
        return data as Data
    }

    // MARK: - Pagination

    private struct PageContent { var rows: [PageRow] }
    private enum PageRow {
        case categoryHeader(CheckCategory)
        case check(Check)
    }

    private static func paginate(report: QCReport, pageRect: CGRect) -> [PageContent] {
        let firstPageBudget = 22
        let nextPageBudget = 42

        var pages: [PageContent] = []
        var current = PageContent(rows: [])
        var budget = firstPageBudget

        for category in CheckCategory.allCases {
            let group = report.checks.filter { $0.category == category }
            guard !group.isEmpty else { continue }
            if budget < 4 {
                pages.append(current); current = PageContent(rows: []); budget = nextPageBudget
            }
            current.rows.append(.categoryHeader(category))
            budget -= 2

            for check in group {
                let cost = check.detail == nil ? 2 : 3
                if budget < cost {
                    pages.append(current); current = PageContent(rows: []); budget = nextPageBudget
                }
                current.rows.append(.check(check))
                budget -= cost
            }
        }
        if !current.rows.isEmpty || pages.isEmpty { pages.append(current) }
        return pages
    }

    // MARK: - Page drawing

    private static func drawPage(_ page: PageContent, pageIndex: Int, totalPages: Int,
                                 in pageRect: CGRect, report: QCReport) {
        let margin: CGFloat = 36
        var cursorY = pageRect.height - margin

        if pageIndex == 0 {
            cursorY = drawCover(report: report, in: pageRect, margin: margin, startY: cursorY)
        } else {
            cursorY = drawPageHeader(report: report, in: pageRect, margin: margin, startY: cursorY)
        }

        cursorY -= 4
        _ = drawRows(page.rows, in: pageRect, margin: margin, startY: cursorY, report: report)

        drawFooter(report: report, pageIndex: pageIndex, totalPages: totalPages,
                   pageRect: pageRect, margin: margin)
    }

    // MARK: - Cover (first page)

    private static func drawCover(report: QCReport, in pageRect: CGRect,
                                  margin: CGFloat, startY: CGFloat) -> CGFloat {
        var y = startY

        let logoSize: CGFloat = 56
        let logoX = margin
        let logoY = y - logoSize
        drawBrandLogo(in: CGRect(x: logoX, y: logoY, width: logoSize, height: logoSize))

        drawString("MisiQC Pro",
                   at: CGPoint(x: logoX + logoSize + 14, y: logoY + logoSize - 26),
                   font: .systemFont(ofSize: 22, weight: .heavy))
        drawString(L10n.t(.rptPDFSubtitle, report.locale),
                   at: CGPoint(x: logoX + logoSize + 14, y: logoY + logoSize - 42),
                   font: .systemFont(ofSize: 10.5, weight: .medium),
                   color: NSColor(white: 0.35, alpha: 1))

        let profileText = report.spec.name + " · " + report.spec.specVersion
        drawProfilePill(text: profileText,
                        accent: channelColor(report.spec.id),
                        at: CGPoint(x: pageRect.width - margin, y: logoY + logoSize - 20))

        y = logoY - 16

        let formatter = DateFormatter()
        formatter.dateFormat = L10n.t(.rptDateFormat, report.locale)
        let info: [(String, String)] = [
            (L10n.t(.rptInfoFile, report.locale),       report.fileURL.lastPathComponent),
            (L10n.t(.rptInfoProfile, report.locale),    report.spec.name + " — " + report.spec.specVersion),
            (L10n.t(.rptInfoDuration, report.locale),   durationString(report.content.totalDurationSec)),
            (L10n.t(.rptInfoAnalyzedAt, report.locale), formatter.string(from: report.analyzedAt))
        ]
        let infoBoxRect = CGRect(x: margin, y: y - CGFloat(info.count) * 16 - 14,
                                 width: pageRect.width - margin * 2,
                                 height: CGFloat(info.count) * 16 + 12)
        NSColor(white: 0.97, alpha: 1).setFill()
        NSBezierPath(roundedRect: infoBoxRect, xRadius: 8, yRadius: 8).fill()
        NSColor(white: 0.85, alpha: 1).setStroke()
        let infoBorder = NSBezierPath(roundedRect: infoBoxRect, xRadius: 8, yRadius: 8)
        infoBorder.lineWidth = 0.5
        infoBorder.stroke()

        for (i, (label, value)) in info.enumerated() {
            let lineY = infoBoxRect.maxY - 16 - CGFloat(i) * 16
            drawString(label.uppercased(),
                       at: CGPoint(x: infoBoxRect.minX + 14, y: lineY),
                       font: .systemFont(ofSize: 8.5, weight: .bold),
                       color: NSColor(white: 0.45, alpha: 1))
            drawString(value,
                       at: CGPoint(x: infoBoxRect.minX + 100, y: lineY),
                       font: .systemFont(ofSize: 10, weight: .medium),
                       maxWidth: infoBoxRect.width - 110)
        }
        y = infoBoxRect.minY - 14

        y = drawVerdictBanner(report: report, in: pageRect, margin: margin, startY: y)
        y -= 12

        y = drawStatStrip(report: report, in: pageRect, margin: margin, startY: y)
        y -= 8

        return y
    }

    private static func drawPageHeader(report: QCReport, in pageRect: CGRect,
                                       margin: CGFloat, startY: CGFloat) -> CGFloat {
        let y = startY
        drawBrandLogo(in: CGRect(x: margin, y: y - 22, width: 22, height: 22))
        drawString(L10n.t(.rptPDFContinued, report.locale),
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

    // MARK: - Verdict banner

    private static func drawVerdictBanner(report: QCReport, in pageRect: CGRect,
                                          margin: CGFloat, startY: CGFloat) -> CGFloat {
        let height: CGFloat = 56
        let rect = CGRect(x: margin, y: startY - height,
                          width: pageRect.width - margin * 2, height: height)
        let accent = verdictColor(report.verdict)

        accent.withAlphaComponent(0.12).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10).fill()
        accent.withAlphaComponent(0.45).setStroke()
        let border = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)
        border.lineWidth = 0.8
        border.stroke()

        let dotRect = CGRect(x: rect.minX + 16, y: rect.midY - 14, width: 28, height: 28)
        accent.setFill()
        NSBezierPath(ovalIn: dotRect).fill()
        let symbol = symbolText(for: report.verdict)
        let symFont = NSFont.systemFont(ofSize: 16, weight: .heavy)
        let symW = (symbol as NSString).size(withAttributes: [.font: symFont]).width
        drawString(symbol,
                   at: CGPoint(x: dotRect.midX - symW / 2, y: dotRect.midY - 8),
                   font: symFont, color: .white)

        drawString(L10n.t(.rptVerdictGlobal, report.locale),
                   at: CGPoint(x: dotRect.maxX + 14, y: rect.midY + 5),
                   font: .systemFont(ofSize: 8.5, weight: .bold),
                   color: NSColor(white: 0.45, alpha: 1))
        drawString(report.verdict.localizedName(report.locale).uppercased(),
                   at: CGPoint(x: dotRect.maxX + 14, y: rect.midY - 14),
                   font: .systemFont(ofSize: 16, weight: .heavy),
                   color: accent)

        return rect.minY
    }

    // MARK: - Stat strip

    private static func drawStatStrip(report: QCReport, in pageRect: CGRect,
                                      margin: CGFloat, startY: CGFloat) -> CGFloat {
        let height: CGFloat = 64
        let gap: CGFloat = 8
        let cardW = (pageRect.width - margin * 2 - gap * 3) / 4

        struct Stat {
            let label: String
            let value: String
            let bg: NSColor
            let accent: NSColor
        }
        let stats: [Stat] = [
            .init(label: L10n.t(.statFound, report.locale), value: "\(report.checks.count)", bg: tintBlue,  accent: accentBlue),
            .init(label: L10n.t(.statPass, report.locale),  value: "\(report.passCount)",    bg: tintMint,  accent: accentMint),
            .init(label: L10n.t(.statWarn, report.locale),  value: "\(report.warningCount)", bg: tintPeach, accent: accentPeach),
            .init(label: L10n.t(.statFail, report.locale),  value: "\(report.failCount)",    bg: tintRed,   accent: accentRed)
        ]
        for (i, s) in stats.enumerated() {
            let x = margin + CGFloat(i) * (cardW + gap)
            let rect = CGRect(x: x, y: startY - height, width: cardW, height: height)
            s.bg.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 9, yRadius: 9).fill()
            s.accent.withAlphaComponent(0.25).setStroke()
            let border = NSBezierPath(roundedRect: rect, xRadius: 9, yRadius: 9)
            border.lineWidth = 0.5
            border.stroke()

            drawString(s.label.uppercased(),
                       at: CGPoint(x: rect.minX + 12, y: rect.maxY - 18),
                       font: .systemFont(ofSize: 8.5, weight: .bold),
                       color: s.accent,
                       maxWidth: cardW - 20)
            let vFont = NSFont.systemFont(ofSize: 22, weight: .heavy)
            let vW = (s.value as NSString).size(withAttributes: [.font: vFont]).width
            drawString(s.value,
                       at: CGPoint(x: rect.midX - vW / 2, y: rect.minY + 8),
                       font: vFont)
        }
        return startY - height
    }

    // MARK: - Rows

    private static func drawRows(_ rows: [PageRow], in pageRect: CGRect, margin: CGFloat,
                                 startY: CGFloat, report: QCReport) -> CGFloat {
        var y = startY
        let leftCol = margin
        let labelW: CGFloat = 195
        let expectedW: CGFloat = 130
        let actualW: CGFloat = pageRect.width - margin * 2 - labelW - expectedW - 26

        for row in rows {
            switch row {
            case .categoryHeader(let cat):
                y -= 4
                let labelStr = cat.localizedName(report.locale).uppercased()
                let labelFont = NSFont.systemFont(ofSize: 9, weight: .heavy)
                let labelWidth = (labelStr as NSString)
                    .size(withAttributes: [.font: labelFont]).width
                let chipRect = CGRect(x: leftCol, y: y - 18,
                                      width: labelWidth + 18, height: 16)
                let catColor = categoryColor(cat)
                catColor.withAlphaComponent(0.16).setFill()
                NSBezierPath(roundedRect: chipRect, xRadius: 8, yRadius: 8).fill()
                drawString(labelStr,
                           at: CGPoint(x: chipRect.minX + 9, y: chipRect.midY - 4),
                           font: labelFont, color: catColor)
                NSColor(white: 0.85, alpha: 1).setStroke()
                let line = NSBezierPath()
                line.move(to: CGPoint(x: chipRect.maxX + 6, y: chipRect.midY))
                line.line(to: CGPoint(x: pageRect.width - margin, y: chipRect.midY))
                line.lineWidth = 0.4
                line.stroke()
                y -= 22

            case .check(let check):
                let baseY = y - 18
                let pipRect = CGRect(x: leftCol, y: baseY + 2, width: 9, height: 9)
                statusColor(check.status).setFill()
                NSBezierPath(ovalIn: pipRect).fill()

                drawString(check.label,
                           at: CGPoint(x: leftCol + 16, y: baseY),
                           font: .systemFont(ofSize: 9.8, weight: .semibold),
                           maxWidth: labelW - 16)

                drawString(check.expected,
                           at: CGPoint(x: leftCol + labelW, y: baseY),
                           font: .systemFont(ofSize: 9.5),
                           color: NSColor(white: 0.4, alpha: 1),
                           maxWidth: expectedW - 8)

                drawString(check.actual,
                           at: CGPoint(x: leftCol + labelW + expectedW, y: baseY),
                           font: .systemFont(ofSize: 9.8, weight: .semibold),
                           color: statusColor(check.status),
                           maxWidth: actualW)
                y -= 16
                if let detail = check.detail {
                    drawString(detail,
                               at: CGPoint(x: leftCol + 16, y: y - 12),
                               font: .systemFont(ofSize: 8.5),
                               color: NSColor(white: 0.5, alpha: 1),
                               maxWidth: pageRect.width - margin * 2 - 16)
                    y -= 13
                }
            }
        }
        return y
    }

    // MARK: - Timeline signal graph

    private struct TimelineLaneInfo {
        let name: String
        let color: NSColor
        let description: String
    }

    private static func timelineLanes(locale: AppLocale) -> [TimelineLaneInfo] {
        [
            .init(name: "YAVG",
                  color: NSColor(calibratedRed: 0.86, green: 0.74, blue: 0.10, alpha: 1),
                  description: L10n.t(.timelineLegendYAVG, locale)),
            .init(name: "YMIN",
                  color: NSColor(calibratedRed: 0.20, green: 0.55, blue: 0.95, alpha: 1),
                  description: L10n.t(.timelineLegendYMIN, locale)),
            .init(name: "YMAX",
                  color: NSColor(calibratedRed: 0.92, green: 0.27, blue: 0.27, alpha: 1),
                  description: L10n.t(.timelineLegendYMAX, locale)),
            .init(name: "BRNG",
                  color: NSColor(calibratedRed: 0.94, green: 0.51, blue: 0.11, alpha: 1),
                  description: L10n.t(.timelineLegendBRNG, locale)),
            .init(name: "TOUT",
                  color: NSColor(calibratedRed: 0.65, green: 0.20, blue: 0.75, alpha: 1),
                  description: L10n.t(.timelineLegendTOUT, locale)),
            .init(name: "VREP",
                  color: NSColor(calibratedRed: 0.13, green: 0.69, blue: 0.41, alpha: 1),
                  description: L10n.t(.timelineLegendVREP, locale))
        ]
    }

    /// Dedicated A4-landscape page that holds the full timeline plus a verbose
    /// legend that explains each metric — printed as the very last page so the
    /// graph is readable.
    private static func drawTimelinePage(report: QCReport, series: TimeSeriesReport,
                                         in pageRect: CGRect, pageIndex: Int, totalPages: Int) {
        let margin: CGFloat = 36
        var y = pageRect.height - margin

        drawBrandLogo(in: CGRect(x: margin, y: y - 26, width: 26, height: 26))
        drawString(L10n.t(.timelineTitle, report.locale).uppercased(),
                   at: CGPoint(x: margin + 34, y: y - 16),
                   font: .systemFont(ofSize: 13, weight: .heavy),
                   color: accentBlue)
        let subLabel = report.spec.name + " · " + report.spec.specVersion
        let sFont = NSFont.systemFont(ofSize: 10, weight: .medium)
        let sw = (subLabel as NSString).size(withAttributes: [.font: sFont]).width
        drawString(subLabel,
                   at: CGPoint(x: pageRect.width - margin - sw, y: y - 16),
                   font: sFont, color: NSColor(white: 0.45, alpha: 1))
        y -= 36

        // Tall chart spanning the full width.
        let chartHeight: CGFloat = 320
        let chartRect = CGRect(x: margin, y: y - chartHeight,
                               width: pageRect.width - margin * 2, height: chartHeight)
        NSColor(white: 0.985, alpha: 1).setFill()
        NSBezierPath(roundedRect: chartRect, xRadius: 8, yRadius: 8).fill()
        NSColor(white: 0.85, alpha: 1).setStroke()
        let border = NSBezierPath(roundedRect: chartRect, xRadius: 8, yRadius: 8)
        border.lineWidth = 0.5
        border.stroke()

        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()
        ctx.addRect(chartRect.insetBy(dx: 4, dy: 4))
        ctx.clip()

        let yMaxValue = Double((1 << series.bitDepth) - 1)
        let innerRect = chartRect.insetBy(dx: 12, dy: 12)

        // Legal-range guides.
        ctx.setStrokeColor(NSColor(white: 0.7, alpha: 0.55).cgColor)
        ctx.setLineWidth(0.5)
        ctx.setLineDash(phase: 0, lengths: [4, 4])
        for fraction in [0.0625, 0.918] {
            let yPos = innerRect.minY + innerRect.height * CGFloat(fraction)
            ctx.move(to: CGPoint(x: innerRect.minX, y: yPos))
            ctx.addLine(to: CGPoint(x: innerRect.maxX, y: yPos))
        }
        ctx.strokePath()
        ctx.setLineDash(phase: 0, lengths: [])

        drawEnvelope(ctx: ctx, series: series, rect: innerRect, yMaxValue: yMaxValue)
        drawLumaLine(ctx: ctx, series: series, rect: innerRect,
                     color: NSColor(calibratedRed: 0.86, green: 0.74, blue: 0.10, alpha: 1),
                     lineWidth: 1.2,
                     keyPath: { $0.yAvg / yMaxValue })
        drawHazardLine(ctx: ctx, series: series, rect: innerRect,
                       color: NSColor(calibratedRed: 0.94, green: 0.51, blue: 0.11, alpha: 1),
                       lineWidth: 0.9, keyPath: { $0.brng })
        drawHazardLine(ctx: ctx, series: series, rect: innerRect,
                       color: NSColor(calibratedRed: 0.65, green: 0.20, blue: 0.75, alpha: 1),
                       lineWidth: 0.9, keyPath: { $0.tout })
        drawHazardLine(ctx: ctx, series: series, rect: innerRect,
                       color: NSColor(calibratedRed: 0.13, green: 0.69, blue: 0.41, alpha: 1),
                       lineWidth: 0.9, keyPath: { $0.vrep })

        ctx.restoreGState()

        // Timecode ruler at the bottom of the chart.
        drawTimelineRuler(ctx: ctx, rect: chartRect, durationSec: series.durationSec)

        y = chartRect.minY - 18

        // Verbose legend grid: 2 columns × 3 rows.
        drawString(L10n.t(.timelineHelpTitle, report.locale).uppercased(),
                   at: CGPoint(x: margin, y: y - 12),
                   font: .systemFont(ofSize: 9, weight: .heavy),
                   color: accentBlue)
        y -= 18

        let lanes = timelineLanes(locale: report.locale)
        let colW = (pageRect.width - margin * 2 - 16) / 2
        let rowH: CGFloat = 38
        for (i, lane) in lanes.enumerated() {
            let col = i % 2
            let row = i / 2
            let cellX = margin + CGFloat(col) * (colW + 16)
            let cellY = y - CGFloat(row + 1) * rowH

            let swatch = CGRect(x: cellX, y: cellY + rowH - 10, width: 14, height: 4)
            lane.color.setFill()
            NSBezierPath(rect: swatch).fill()
            drawString(lane.name,
                       at: CGPoint(x: cellX + 22, y: cellY + rowH - 14),
                       font: .systemFont(ofSize: 10, weight: .heavy),
                       color: lane.color)
            drawWrappedString(lane.description,
                              at: CGPoint(x: cellX + 22, y: cellY + rowH - 28),
                              font: .systemFont(ofSize: 8.5),
                              color: NSColor(white: 0.35, alpha: 1),
                              maxWidth: colW - 26,
                              maxHeight: 24)
        }
        y -= CGFloat((lanes.count + 1) / 2) * rowH + 8

        drawString(L10n.t(.timelineHelpNote, report.locale),
                   at: CGPoint(x: margin, y: y - 12),
                   font: .systemFont(ofSize: 8.5, weight: .medium),
                   color: NSColor(white: 0.5, alpha: 1),
                   maxWidth: pageRect.width - margin * 2)

        drawFooter(report: report, pageIndex: pageIndex, totalPages: totalPages,
                   pageRect: pageRect, margin: margin)
    }

    private static func drawTimelineRuler(ctx: CGContext, rect: CGRect, durationSec: Double) {
        guard durationSec > 0 else { return }
        let baseY = rect.minY + 6
        let labelY = baseY + 2
        let targetSpacing: CGFloat = 110
        let approxTicks = max(2, Int(rect.width / targetSpacing))
        let rawStep = durationSec / Double(approxTicks)
        let step = niceTimeStep(rawStep)
        let count = Int(durationSec / step) + 1

        ctx.setStrokeColor(NSColor(white: 0.55, alpha: 1).cgColor)
        ctx.setLineWidth(0.5)
        ctx.beginPath()
        for i in 0...count {
            let t = Double(i) * step
            if t > durationSec { break }
            let x = rect.minX + 12 + (rect.width - 24) * CGFloat(t / durationSec)
            ctx.move(to: CGPoint(x: x, y: baseY))
            ctx.addLine(to: CGPoint(x: x, y: baseY + 5))
        }
        ctx.strokePath()

        let labelFont = NSFont.monospacedDigitSystemFont(ofSize: 7.5, weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: NSColor(white: 0.35, alpha: 1)
        ]
        for i in 0...count {
            let t = Double(i) * step
            if t > durationSec { break }
            let x = rect.minX + 12 + (rect.width - 24) * CGFloat(t / durationSec)
            let label = timecodeLabel(t)
            let size = (label as NSString).size(withAttributes: attrs)
            (label as NSString).draw(at: CGPoint(x: x - size.width / 2, y: labelY),
                                     withAttributes: attrs)
        }
    }

    private static func niceTimeStep(_ raw: Double) -> Double {
        let steps: [Double] = [
            1, 2, 5, 10, 15, 30,
            60, 120, 300, 600, 900, 1800,
            3600, 7200, 18000
        ]
        for s in steps where s >= raw { return s }
        return steps.last ?? raw
    }

    private static func timecodeLabel(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    private static func drawWrappedString(_ s: String, at point: CGPoint, font: NSFont,
                                          color: NSColor, maxWidth: CGFloat, maxHeight: CGFloat) {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byWordWrapping
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: style
        ]
        let rect = CGRect(x: point.x, y: point.y - maxHeight + 12,
                          width: maxWidth, height: maxHeight)
        (s as NSString).draw(in: rect, withAttributes: attrs)
    }

    private static func drawEnvelope(ctx: CGContext, series: TimeSeriesReport,
                                     rect: CGRect, yMaxValue: Double) {
        let count = series.points.count
        guard count > 1 else { return }
        let dx = rect.width / CGFloat(count - 1)

        // Build upper (YMAX) and lower (YMIN) point arrays in PDF coords
        // (y grows upward → fraction maps directly).
        var upperPoints: [CGPoint] = []
        var lowerPoints: [CGPoint] = []
        for (i, p) in series.points.enumerated() {
            let x = rect.minX + CGFloat(i) * dx
            let yHi = rect.minY + rect.height * CGFloat(Double(p.yMax) / yMaxValue)
            let yLo = rect.minY + rect.height * CGFloat(Double(p.yMin) / yMaxValue)
            upperPoints.append(CGPoint(x: x, y: yHi))
            lowerPoints.append(CGPoint(x: x, y: yLo))
        }

        // Filled envelope.
        ctx.beginPath()
        ctx.move(to: upperPoints[0])
        for p in upperPoints.dropFirst() { ctx.addLine(to: p) }
        for p in lowerPoints.reversed() { ctx.addLine(to: p) }
        ctx.closePath()
        ctx.setFillColor(NSColor(calibratedRed: 0.2, green: 0.4, blue: 0.8, alpha: 0.18).cgColor)
        ctx.fillPath()

        // Outline of upper and lower curves.
        ctx.setLineWidth(0.6)
        ctx.setStrokeColor(NSColor(calibratedRed: 0.92, green: 0.27, blue: 0.27, alpha: 0.85).cgColor)
        ctx.beginPath()
        ctx.move(to: upperPoints[0])
        for p in upperPoints.dropFirst() { ctx.addLine(to: p) }
        ctx.strokePath()

        ctx.setStrokeColor(NSColor(calibratedRed: 0.20, green: 0.55, blue: 0.95, alpha: 0.85).cgColor)
        ctx.beginPath()
        ctx.move(to: lowerPoints[0])
        for p in lowerPoints.dropFirst() { ctx.addLine(to: p) }
        ctx.strokePath()
    }

    private static func drawLumaLine(ctx: CGContext, series: TimeSeriesReport, rect: CGRect,
                                     color: NSColor, lineWidth: CGFloat,
                                     keyPath: (TimeSeriesPoint) -> Double) {
        let count = series.points.count
        guard count > 1 else { return }
        let dx = rect.width / CGFloat(count - 1)
        ctx.setLineWidth(lineWidth)
        ctx.setStrokeColor(color.cgColor)
        ctx.beginPath()
        for (i, p) in series.points.enumerated() {
            let v = max(0, min(1, keyPath(p)))
            let x = rect.minX + CGFloat(i) * dx
            let y = rect.minY + rect.height * CGFloat(v)
            if i == 0 { ctx.move(to: CGPoint(x: x, y: y)) }
            else      { ctx.addLine(to: CGPoint(x: x, y: y)) }
        }
        ctx.strokePath()
    }

    private static func drawHazardLine(ctx: CGContext, series: TimeSeriesReport, rect: CGRect,
                                       color: NSColor, lineWidth: CGFloat,
                                       keyPath: (TimeSeriesPoint) -> Double) {
        let count = series.points.count
        guard count > 1 else { return }
        let dx = rect.width / CGFloat(count - 1)
        ctx.setLineWidth(lineWidth)
        ctx.setStrokeColor(color.cgColor)
        ctx.beginPath()
        for (i, p) in series.points.enumerated() {
            // ×10 amplification so 1–10% OOR shows up clearly.
            let v = max(0, min(1, keyPath(p) * 10))
            let x = rect.minX + CGFloat(i) * dx
            let y = rect.minY + rect.height * CGFloat(v)
            if i == 0 { ctx.move(to: CGPoint(x: x, y: y)) }
            else      { ctx.addLine(to: CGPoint(x: x, y: y)) }
        }
        ctx.strokePath()
    }

    // MARK: - Footer

    private static func drawFooter(report: QCReport, pageIndex: Int, totalPages: Int,
                                   pageRect: CGRect, margin: CGFloat) {
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let topLine = "MisiQC Pro v\(appVersion) · Profil \(report.spec.specVersion) · Page \(pageIndex + 1)/\(totalPages)"
        drawString(topLine,
                   at: CGPoint(x: margin, y: 26),
                   font: .systemFont(ofSize: 8),
                   color: NSColor(white: 0.55, alpha: 1))

        // Watermark right-aligned at the top of the footer band — discreet but
        // present on every page (anti-piracy + traceability).
        if let watermark = currentLicenseWatermark {
            let wmFont = NSFont.systemFont(ofSize: 7.5, weight: .regular)
            let wmW = (watermark as NSString).size(withAttributes: [.font: wmFont]).width
            drawString(watermark,
                       at: CGPoint(x: pageRect.width - margin - wmW, y: 26),
                       font: wmFont,
                       color: NSColor(white: 0.65, alpha: 1))
        }

        let signature = L10n.t(.rptSignature, report.locale)
        let sigFont = NSFont.systemFont(ofSize: 8, weight: .medium)
        let sigWidth = (signature as NSString)
            .size(withAttributes: [.font: sigFont]).width
        drawString(signature,
                   at: CGPoint(x: (pageRect.width - sigWidth) / 2, y: 14),
                   font: sigFont,
                   color: NSColor(white: 0.45, alpha: 1))

        NSColor(white: 0.88, alpha: 1).setStroke()
        let sep = NSBezierPath()
        sep.move(to: CGPoint(x: margin, y: 38))
        sep.line(to: CGPoint(x: pageRect.width - margin, y: 38))
        sep.lineWidth = 0.4
        sep.stroke()
    }

    // MARK: - Brand logo

    /// Draws the logo into a target rect by rasterising it once into an
    /// `NSImage` (using the same Core Graphics routine as the app icon),
    /// then compositing it. This sidesteps any coordinate-system mismatch
    /// between the PDF context and direct CG drawing.
    private static func drawBrandLogo(in rect: CGRect) {
        let pixelSize = max(64, Int(rect.width * 4)) // 4x for crisp rendering
        let image = brandLogoImage(pixelSize: pixelSize)
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    private static func brandLogoImage(pixelSize: Int) -> NSImage {
        let size = CGFloat(pixelSize)
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelSize,
            pixelsHigh: pixelSize,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 4 * pixelSize,
            bitsPerPixel: 32
        ) else {
            return NSImage(size: NSSize(width: 1, height: 1))
        }

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
        ctx.addPath(bgPath)
        ctx.clip()

        let colorspace = CGColorSpaceCreateDeviceRGB()
        let colors = [
            CGColor(red: 0.176, green: 0.847, blue: 1.000, alpha: 1),
            CGColor(red: 0.443, green: 0.357, blue: 1.000, alpha: 1),
            CGColor(red: 1.000, green: 0.310, blue: 0.557, alpha: 1)
        ] as CFArray
        let gradient = CGGradient(colorsSpace: colorspace, colors: colors,
                                  locations: [0, 0.55, 1])!
        ctx.drawLinearGradient(gradient,
                               start: CGPoint(x: 0, y: size),
                               end: CGPoint(x: size, y: 0),
                               options: [])

        let hl = CGGradient(colorsSpace: colorspace, colors: [
            CGColor(red: 1, green: 1, blue: 1, alpha: 0.4),
            CGColor(red: 1, green: 1, blue: 1, alpha: 0)
        ] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(hl, start: CGPoint(x: 0, y: size),
                               end: CGPoint(x: 0, y: size * 0.5), options: [])

        ctx.restoreGState()

        // Waveform → checkmark stroke (coords in SwiftUI convention, flipped for CG).
        let lineWidth = size * 0.105
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

        let image = NSImage(size: NSSize(width: size, height: size))
        image.addRepresentation(bitmap)
        return image
    }

    // MARK: - Misc helpers

    private static func drawProfilePill(text: String, accent: NSColor, at rightAnchor: CGPoint) {
        let font = NSFont.systemFont(ofSize: 9.5, weight: .heavy)
        let textSize = (text as NSString).size(withAttributes: [.font: font])
        let padH: CGFloat = 12, padV: CGFloat = 6
        let pillRect = CGRect(x: rightAnchor.x - textSize.width - padH * 2,
                              y: rightAnchor.y - padV - textSize.height / 2,
                              width: textSize.width + padH * 2,
                              height: textSize.height + padV * 2)
        accent.withAlphaComponent(0.16).setFill()
        NSBezierPath(roundedRect: pillRect, xRadius: pillRect.height / 2,
                     yRadius: pillRect.height / 2).fill()
        accent.withAlphaComponent(0.5).setStroke()
        let border = NSBezierPath(roundedRect: pillRect, xRadius: pillRect.height / 2,
                                  yRadius: pillRect.height / 2)
        border.lineWidth = 0.5
        border.stroke()
        drawString(text,
                   at: CGPoint(x: pillRect.minX + padH, y: pillRect.minY + padV),
                   font: font, color: accent)
    }

    private static func drawString(_ s: String, at point: CGPoint, font: NSFont,
                                   color: NSColor = .black, maxWidth: CGFloat? = nil) {
        if let maxWidth {
            // Force single-line with ellipsis truncation so a long value never
            // wraps onto two lines and collides with the next row.
            let style = NSMutableParagraphStyle()
            style.lineBreakMode = .byTruncatingTail
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: style
            ]
            let rect = CGRect(x: point.x, y: point.y, width: maxWidth, height: font.pointSize + 4)
            (s as NSString).draw(in: rect, withAttributes: attrs)
        } else {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color
            ]
            (s as NSString).draw(at: point, withAttributes: attrs)
        }
    }

    // MARK: - Tokens

    private static let tintBlue   = NSColor(calibratedRed: 0.886, green: 0.945, blue: 1.000, alpha: 1)
    private static let tintLilac  = NSColor(calibratedRed: 0.941, green: 0.918, blue: 1.000, alpha: 1)
    private static let tintMint   = NSColor(calibratedRed: 0.886, green: 0.973, blue: 0.929, alpha: 1)
    private static let tintPeach  = NSColor(calibratedRed: 1.000, green: 0.929, blue: 0.871, alpha: 1)
    private static let tintRed    = NSColor(calibratedRed: 1.000, green: 0.910, blue: 0.910, alpha: 1)
    private static let accentBlue   = NSColor(calibratedRed: 0.180, green: 0.475, blue: 0.960, alpha: 1)
    private static let accentLilac  = NSColor(calibratedRed: 0.490, green: 0.388, blue: 0.949, alpha: 1)
    private static let accentMint   = NSColor(calibratedRed: 0.118, green: 0.682, blue: 0.408, alpha: 1)
    private static let accentPeach  = NSColor(calibratedRed: 0.937, green: 0.510, blue: 0.114, alpha: 1)
    private static let accentRed    = NSColor(calibratedRed: 0.851, green: 0.196, blue: 0.196, alpha: 1)

    private static func verdictColor(_ v: CheckStatus) -> NSColor {
        switch v {
        case .pass: return accentMint
        case .warning: return accentPeach
        case .fail: return NSColor(calibratedRed: 0.81, green: 0.18, blue: 0.22, alpha: 1)
        }
    }

    private static func statusColor(_ s: CheckStatus) -> NSColor { verdictColor(s) }

    private static func symbolText(for v: CheckStatus) -> String {
        switch v {
        case .pass: return "✓"
        case .warning: return "!"
        case .fail: return "✕"
        }
    }

    private static func categoryColor(_ c: CheckCategory) -> NSColor {
        switch c {
        case .container: return accentBlue
        case .video: return NSColor(calibratedRed: 0.55, green: 0.39, blue: 0.91, alpha: 1)
        case .audio: return accentPeach
        case .loudness: return NSColor(calibratedRed: 0.13, green: 0.61, blue: 0.95, alpha: 1)
        case .structure: return accentMint
        }
    }

    private static func channelColor(_ id: String) -> NSColor {
        switch id {
        case "francetv": return NSColor(calibratedRed: 0.318, green: 0.482, blue: 1.000, alpha: 1)
        case "m6": return NSColor(calibratedRed: 1.000, green: 0.392, blue: 0.580, alpha: 1)
        case "tf1": return NSColor(calibratedRed: 1.000, green: 0.561, blue: 0.243, alpha: 1)
        case "canalplus": return NSColor(calibratedRed: 0.580, green: 0.412, blue: 0.949, alpha: 1)
        case "arte": return NSColor(calibratedRed: 0.992, green: 0.690, blue: 0.000, alpha: 1)
        case "netflix": return NSColor(calibratedRed: 0.898, green: 0.071, blue: 0.118, alpha: 1)
        case "amazon": return NSColor(calibratedRed: 0.000, green: 0.659, blue: 0.835, alpha: 1)
        case "disney": return NSColor(calibratedRed: 0.067, green: 0.094, blue: 0.337, alpha: 1)
        case "appletv": return NSColor(calibratedRed: 0.000, green: 0.000, blue: 0.000, alpha: 1)
        case "max": return NSColor(calibratedRed: 0.000, green: 0.400, blue: 1.000, alpha: 1)
        case "paramount": return NSColor(calibratedRed: 0.000, green: 0.388, blue: 0.937, alpha: 1)
        case "tv5monde": return NSColor(calibratedRed: 0.929, green: 0.000, blue: 0.184, alpha: 1)
        case "france24": return NSColor(calibratedRed: 0.871, green: 0.000, blue: 0.114, alpha: 1)
        case "lequipe": return NSColor(calibratedRed: 0.945, green: 0.812, blue: 0.000, alpha: 1)
        case "gulli": return NSColor(calibratedRed: 0.945, green: 0.404, blue: 0.000, alpha: 1)
        case "rtbf": return NSColor(calibratedRed: 0.890, green: 0.114, blue: 0.176, alpha: 1)
        case "ardzdf": return NSColor(calibratedRed: 0.012, green: 0.122, blue: 0.345, alpha: 1)
        case "rai": return NSColor(calibratedRed: 0.012, green: 0.318, blue: 0.624, alpha: 1)
        case "bbc": return NSColor(calibratedRed: 0.067, green: 0.067, blue: 0.067, alpha: 1)
        case "dpp": return NSColor(calibratedRed: 0.114, green: 0.400, blue: 0.620, alpha: 1)
        case "youtube": return NSColor(calibratedRed: 1.000, green: 0.000, blue: 0.000, alpha: 1)
        case "vimeo": return NSColor(calibratedRed: 0.106, green: 0.694, blue: 0.871, alpha: 1)
        default: return .darkGray
        }
    }

    private static func durationString(_ s: Double?) -> String {
        guard let s else { return "—" }
        let h = Int(s) / 3600
        let m = (Int(s) % 3600) / 60
        let sec = Int(s) % 60
        return String(format: "%02d:%02d:%02d", h, m, sec)
    }
}
