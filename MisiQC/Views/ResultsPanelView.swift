import SwiftUI

/// Right-column results panel. Shows: empty state / running progress / finished report.
struct ResultsPanelView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(content)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.18), lineWidth: 1)
            )
    }

    @ViewBuilder
    private var content: some View {
        if state.isAnalyzing {
            runningStages
        } else if let report = state.lastReport {
            ScrollView { checksList(report) }
        } else {
            emptyState
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.secondary)
            Text(state.t(.emptyState))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text(state.t(.emptyHint))
                .font(.system(size: 11))
                .foregroundStyle(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Running stages

    private var runningStages: some View {
        VStack(spacing: 14) {
            ProgressView().controlSize(.regular)
            Text(state.t(.analyzing))
                .font(.system(size: 13, weight: .semibold))
            let columns = [
                GridItem(.flexible(), alignment: .leading),
                GridItem(.flexible(), alignment: .leading)
            ]
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(QCEngine.Stage.allCases, id: \.self) { stage in
                    HStack(spacing: 8) {
                        stageIcon(stage)
                        Text(stage.localizedName(state.locale))
                            .font(.system(size: 12))
                            .foregroundStyle(stageColor(stage))
                            .lineLimit(1)
                    }
                }
            }
            .padding(.top, 6)
            .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private func stageIcon(_ stage: QCEngine.Stage) -> some View {
        let current = state.currentStage
        let pos = QCEngine.Stage.allCases.firstIndex(of: stage) ?? 0
        let cur = current.flatMap { QCEngine.Stage.allCases.firstIndex(of: $0) } ?? -1
        return Group {
            if pos < cur {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Brand.accentMint)
            } else if pos == cur {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: "circle").foregroundStyle(.secondary.opacity(0.35))
            }
        }
        .frame(width: 14, height: 14)
    }

    private func stageColor(_ stage: QCEngine.Stage) -> Color {
        let current = state.currentStage
        let pos = QCEngine.Stage.allCases.firstIndex(of: stage) ?? 0
        let cur = current.flatMap { QCEngine.Stage.allCases.firstIndex(of: $0) } ?? -1
        if pos < cur { return .secondary }
        if pos == cur { return .primary }
        return .secondary.opacity(0.6)
    }

    // MARK: - Checks list

    @State private var showingTimelineHelp = false

    private func checksList(_ report: QCReport) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let series = report.content.timeSeries, !series.points.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    SectionHeader(
                        title: state.t(.timelineTitle),
                        icon: "waveform.path.ecg",
                        trailing: AnyView(
                            Button {
                                showingTimelineHelp.toggle()
                            } label: {
                                Image(systemName: "questionmark.circle.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Brand.accentBlue)
                            }
                            .buttonStyle(.plain)
                            .help(state.t(.timelineHelpTitle))
                            .popover(isPresented: $showingTimelineHelp,
                                     arrowEdge: .top) {
                                TimelineHelpPopover()
                                    .environment(state)
                            }
                        )
                    )
                    TimelineGraphView(series: series, bitDepth: series.bitDepth)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(nsColor: .textBackgroundColor))
                        )
                }
            }
            ForEach(CheckCategory.allCases, id: \.self) { cat in
                let rows = report.checks.filter { $0.category == cat }
                if !rows.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        SectionHeader(title: cat.localizedName(state.locale), icon: categoryIcon(cat))
                        VStack(spacing: 0) {
                            ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                                CheckRowView(check: row)
                                    .padding(.horizontal, 12)
                                if idx < rows.count - 1 {
                                    Divider().padding(.leading, 46)
                                }
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(nsColor: .textBackgroundColor))
                        )
                    }
                }
            }
        }
        .padding(16)
    }

    private func categoryIcon(_ cat: CheckCategory) -> String {
        switch cat {
        case .container: return "shippingbox"
        case .video: return "film"
        case .audio: return "waveform"
        case .loudness: return "speaker.wave.3"
        case .structure: return "timer"
        }
    }
}
