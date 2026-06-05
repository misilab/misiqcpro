import SwiftUI

/// Help popover anchored to the "?" button next to the Timeline header.
/// Walks the user through the meaning of every lane on the chart.
struct TimelineHelpPopover: View {
    @Environment(AppState.self) private var state

    private struct LegendItem: Identifiable {
        let id = UUID()
        let symbol: String
        let color: Color
        let textKey: L10n.Key
    }

    private var items: [LegendItem] {
        [
            .init(symbol: "YAVG",
                  color: Color(red: 0.96, green: 0.94, blue: 0.42),
                  textKey: .timelineLegendYAVG),
            .init(symbol: "YMIN",
                  color: Color(red: 0.20, green: 0.55, blue: 0.95),
                  textKey: .timelineLegendYMIN),
            .init(symbol: "YMAX",
                  color: Color(red: 0.92, green: 0.27, blue: 0.27),
                  textKey: .timelineLegendYMAX),
            .init(symbol: "BRNG",
                  color: Color(red: 0.94, green: 0.51, blue: 0.11),
                  textKey: .timelineLegendBRNG),
            .init(symbol: "TOUT",
                  color: Color(red: 0.85, green: 0.20, blue: 0.85),
                  textKey: .timelineLegendTOUT),
            .init(symbol: "VREP",
                  color: Color(red: 0.13, green: 0.69, blue: 0.41),
                  textKey: .timelineLegendVREP)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "waveform.path.ecg")
                    .foregroundStyle(Brand.accentBlue)
                Text(state.t(.timelineHelpTitle))
                    .font(.system(size: 14, weight: .heavy))
            }
            Text(state.t(.timelineHelpIntro))
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(items) { item in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(item.color)
                                .frame(width: 22, height: 4)
                            Text(item.symbol)
                                .font(.system(size: 9, weight: .heavy).monospaced())
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 38)
                        Text(state.t(item.textKey))
                            .font(.system(size: 11))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Divider()

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.bubble.fill")
                    .foregroundStyle(Brand.accentPeach)
                    .font(.system(size: 12))
                Text(state.t(.timelineHelpNote))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(width: 380)
    }
}
