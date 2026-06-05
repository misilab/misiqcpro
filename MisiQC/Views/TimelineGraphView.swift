import SwiftUI

/// Canvas-based time series viewer — draws YMIN / YMAX / YAVG envelope plus
/// BRNG / TOUT / VREP overlays across the full programme duration. Inspired
/// by QCTools' main timeline. Supports horizontal zoom via pinch gesture and
/// the +/− buttons, with a sticky timecode ruler at the top.
struct TimelineGraphView: View {
    let series: TimeSeriesReport
    let bitDepth: Int

    @State private var zoom: CGFloat = 1.0
    private let minZoom: CGFloat = 1.0
    private let maxZoom: CGFloat = 20.0
    private let chartHeight: CGFloat = 140
    private let rulerHeight: CGFloat = 18

    private struct Lane {
        let name: String
        let color: Color
        let valueProvider: (TimeSeriesPoint) -> Double
    }

    private var lanes: [Lane] {
        let yMaxValue = Double((1 << bitDepth) - 1)
        return [
            .init(name: "YAVG", color: Color(red: 0.96, green: 0.94, blue: 0.42),
                  valueProvider: { $0.yAvg / yMaxValue }),
            .init(name: "YMIN", color: Color(red: 0.20, green: 0.55, blue: 0.95),
                  valueProvider: { Double($0.yMin) / yMaxValue }),
            .init(name: "YMAX", color: Color(red: 0.92, green: 0.27, blue: 0.27),
                  valueProvider: { Double($0.yMax) / yMaxValue })
        ]
    }

    private var hazardLanes: [Lane] {
        [
            .init(name: "BRNG", color: Color(red: 0.94, green: 0.51, blue: 0.11),
                  valueProvider: { min(1.0, $0.brng * 10) }),
            .init(name: "TOUT", color: Color(red: 0.85, green: 0.20, blue: 0.85),
                  valueProvider: { min(1.0, $0.tout * 10) }),
            .init(name: "VREP", color: Color(red: 0.13, green: 0.69, blue: 0.41),
                  valueProvider: { min(1.0, $0.vrep * 10) })
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            scrollableChart
        }
    }

    // MARK: - Header (legend + zoom controls)

    private var header: some View {
        HStack(spacing: 14) {
            ForEach(lanes + hazardLanes, id: \.name) { lane in
                HStack(spacing: 4) {
                    Rectangle().fill(lane.color).frame(width: 10, height: 3)
                    Text(lane.name).font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            zoomControls
        }
    }

    private var zoomControls: some View {
        HStack(spacing: 4) {
            zoomButton(icon: "minus.magnifyingglass") { applyZoom(zoom / 1.5) }
            Text(String(format: "%.1f×", zoom))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 38, alignment: .center)
            zoomButton(icon: "plus.magnifyingglass") { applyZoom(zoom * 1.5) }
            zoomButton(icon: "arrow.counterclockwise") { applyZoom(1.0) }
        }
    }

    private func zoomButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 18)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
    }

    private func applyZoom(_ value: CGFloat) {
        withAnimation(.easeInOut(duration: 0.18)) {
            zoom = min(max(value, minZoom), maxZoom)
        }
    }

    // MARK: - Scrollable chart

    private var scrollableChart: some View {
        GeometryReader { geo in
            let baseWidth = geo.size.width
            let contentWidth = baseWidth * zoom
            ScrollView(.horizontal, showsIndicators: true) {
                VStack(spacing: 0) {
                    timecodeRuler(width: contentWidth)
                    chart
                        .frame(width: contentWidth, height: chartHeight)
                }
                .frame(width: contentWidth)
            }
            .frame(height: chartHeight + rulerHeight)
            .background(Color(nsColor: .textBackgroundColor),
                        in: RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            .gesture(
                MagnificationGesture()
                    .onChanged { newValue in
                        applyZoom(zoom * newValue / (newValue > 1 ? 1 : 1))
                    }
            )
        }
        .frame(height: chartHeight + rulerHeight)
    }

    // MARK: - Timecode ruler

    private func timecodeRuler(width: CGFloat) -> some View {
        Canvas { ctx, size in
            let duration = series.durationSec
            guard duration > 0 else { return }

            // Aim for one tick roughly every 90pt of visible space — enough to
            // read but not crowd at high zooms.
            let targetSpacing: Double = 90
            let approxTicks = max(2, Int(size.width / targetSpacing))
            let rawStep = duration / Double(approxTicks)
            let step = niceTimeStep(rawStep)
            let count = Int(duration / step) + 1

            ctx.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .color(Color.secondary.opacity(0.06)))

            for i in 0...count {
                let t = Double(i) * step
                if t > duration { break }
                let x = size.width * CGFloat(t / duration)
                var tick = Path()
                tick.move(to: CGPoint(x: x, y: size.height - 5))
                tick.addLine(to: CGPoint(x: x, y: size.height))
                ctx.stroke(tick, with: .color(.secondary.opacity(0.55)),
                           lineWidth: 0.8)

                let label = timeString(t)
                let text = Text(label).font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(Color.secondary)
                ctx.draw(text, at: CGPoint(x: x + 3, y: 2), anchor: .topLeading)
            }
        }
        .frame(width: width, height: rulerHeight)
    }

    private func niceTimeStep(_ raw: Double) -> Double {
        // Snap to a human-readable step: 1, 2, 5, 10, 15, 30 seconds; then 1, 2,
        // 5, 10, 15, 30 minutes; then 1, 2, 5 hours.
        let steps: [Double] = [
            1, 2, 5, 10, 15, 30,
            60, 120, 300, 600, 900, 1800,
            3600, 7200, 18000
        ]
        for s in steps where s >= raw { return s }
        return steps.last ?? raw
    }

    private func timeString(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Chart drawing

    private var chart: some View {
        Canvas { ctx, size in
            guard !series.points.isEmpty, series.durationSec > 0 else { return }

            let bg = Color.secondary.opacity(0.18)
            for fraction in [0.0625, 0.918] {
                let y = size.height * (1 - fraction)
                var p = Path()
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(p, with: .color(bg), style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
            }

            drawEnvelope(ctx: ctx, size: size)
            drawLine(ctx: ctx, size: size, lane: lanes[0], lineWidth: 1.0)
            for lane in hazardLanes {
                drawLine(ctx: ctx, size: size, lane: lane, lineWidth: 0.8)
            }
        }
    }

    private func drawEnvelope(ctx: GraphicsContext, size: CGSize) {
        let count = series.points.count
        guard count > 1 else { return }
        let dx = size.width / CGFloat(count - 1)
        var upper = Path()
        var lower = Path()
        let yMaxValue = Double((1 << bitDepth) - 1)
        for (i, point) in series.points.enumerated() {
            let x = CGFloat(i) * dx
            let yHi = size.height * CGFloat(1 - Double(point.yMax) / yMaxValue)
            let yLo = size.height * CGFloat(1 - Double(point.yMin) / yMaxValue)
            if i == 0 {
                upper.move(to: CGPoint(x: x, y: yHi))
                lower.move(to: CGPoint(x: x, y: yLo))
            } else {
                upper.addLine(to: CGPoint(x: x, y: yHi))
                lower.addLine(to: CGPoint(x: x, y: yLo))
            }
        }
        var envelope = upper
        var pts: [CGPoint] = []
        lower.forEach { element in
            switch element {
            case .move(let p), .line(let p): pts.append(p)
            default: break
            }
        }
        for p in pts.reversed() { envelope.addLine(to: p) }
        envelope.closeSubpath()
        ctx.fill(envelope, with: .color(Color(red: 0.2, green: 0.4, blue: 0.8, opacity: 0.18)))
        ctx.stroke(upper, with: .color(lanes[2].color.opacity(0.8)), lineWidth: 0.8)
        ctx.stroke(lower, with: .color(lanes[1].color.opacity(0.8)), lineWidth: 0.8)
    }

    private func drawLine(ctx: GraphicsContext, size: CGSize, lane: Lane, lineWidth: CGFloat) {
        let count = series.points.count
        guard count > 1 else { return }
        let dx = size.width / CGFloat(count - 1)
        var path = Path()
        for (i, point) in series.points.enumerated() {
            let v = lane.valueProvider(point)
            let x = CGFloat(i) * dx
            let y = size.height * CGFloat(1 - max(0, min(1, v)))
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else      { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        ctx.stroke(path, with: .color(lane.color), lineWidth: lineWidth)
    }
}
