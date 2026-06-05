import Foundation

/// Writes the QC report in two CSV blocks: a summary of every check, followed
/// by the per-frame signalstats time series. Mirrors the layout of QCTools'
/// CSV export so the file opens cleanly in Excel / Numbers / pandas.
enum CSVExporter {

    static func write(_ report: QCReport, to url: URL) throws {
        var out = ""
        out += headerBlock(report)
        out += "\n"
        out += checksBlock(report)
        out += "\n"
        if let series = report.content.timeSeries, !series.points.isEmpty {
            out += timeSeriesBlock(series)
        }
        try out.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Blocks

    private static func headerBlock(_ report: QCReport) -> String {
        var rows: [(String, String)] = []
        rows.append(("File", report.fileURL.lastPathComponent))
        rows.append(("Profile", "\(report.spec.name) — \(report.spec.specVersion)"))
        rows.append(("Analyzed at", iso.string(from: report.analyzedAt)))
        rows.append(("Verdict", report.verdict.rawValue))
        rows.append(("Passes", "\(report.passCount)"))
        rows.append(("Warnings", "\(report.warningCount)"))
        rows.append(("Failures", "\(report.failCount)"))
        return rows.map { "\(escape($0.0)),\(escape($0.1))" }.joined(separator: "\n") + "\n"
    }

    private static func checksBlock(_ report: QCReport) -> String {
        var lines: [String] = []
        lines.append(["Category", "Label", "Expected", "Actual", "Status", "Detail"]
            .map(escape).joined(separator: ","))
        for c in report.checks {
            lines.append([
                c.category.rawValue,
                c.label,
                c.expected,
                c.actual,
                c.status.rawValue,
                c.detail ?? ""
            ].map(escape).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func timeSeriesBlock(_ series: TimeSeriesReport) -> String {
        var lines: [String] = []
        lines.append("# Per-frame signalstats (sampled every \(series.samplingStride) frames, bit depth \(series.bitDepth))")
        lines.append(["pts_sec", "YAVG", "YMIN", "YMAX", "BRNG", "TOUT", "VREP"]
            .map(escape).joined(separator: ","))
        for p in series.points {
            lines.append([
                String(format: "%.3f", p.pts),
                String(format: "%.2f", p.yAvg),
                "\(p.yMin)",
                "\(p.yMax)",
                String(format: "%.6f", p.brng),
                String(format: "%.6f", p.tout),
                String(format: "%.6f", p.vrep)
            ].joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Utils

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    nonisolated private static func escape(_ value: String) -> String {
        let mustQuote = value.contains(",") || value.contains("\"") || value.contains("\n")
        if !mustQuote { return value }
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}
