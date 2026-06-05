import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            TrialBanner()
            header
            HStack(alignment: .top, spacing: 18) {
                leftColumn
                    .frame(width: 320)
                rightColumn
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 8)
            .frame(maxHeight: .infinity)
            FooterCredit()
        }
        .background(Color(nsColor: NSColor(white: 0.955, alpha: 1)))
        .alert(state.t(.errorTitle), isPresented: Binding(
            get: { state.errorMessage != nil },
            set: { if !$0 { state.errorMessage = nil } }
        )) {
            Button(state.t(.okButton), role: .cancel) { state.errorMessage = nil }
        } message: {
            Text(state.errorMessage ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            BrandLogo(size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(state.t(.appName))
                    .font(.system(size: 20, weight: .heavy))
                Text(state.t(.appSubtitle))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let spec = state.selectedSpec {
                StatusPill(label: spec.specVersion, icon: "tag.fill", tint: .channel(spec.id))
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
    }

    // MARK: - Left column (channels only)

    @State private var showingSpecSheet = false

    @ViewBuilder
    private var leftColumn: some View {
        @Bindable var state = state
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(
                title: state.t(.sectionChannel),
                icon: "antenna.radiowaves.left.and.right",
                trailing: state.selectedSpec.map { _ in
                    AnyView(
                        Button {
                            showingSpecSheet = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.text.magnifyingglass")
                                Text(state.t(.actionShowSpecs))
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Brand.accentBlue)
                        }
                        .buttonStyle(.plain)
                    )
                }
            )
            PermanentScrollView {
                VStack(spacing: 14) {
                    ForEach(SpecRepository.bundledByCategory, id: \.0) { category, ids in
                        let specsInCategory = ids.compactMap { id in
                            state.availableSpecs.first(where: { $0.id == id })
                        }
                        if !specsInCategory.isEmpty {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(category.localizedName(state.locale).uppercased())
                                    .font(.system(size: 10, weight: .heavy))
                                    .tracking(0.8)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 4)
                                    .padding(.top, 4)
                                ForEach(specsInCategory) { spec in
                                    ChannelModeCard(
                                        spec: spec,
                                        isSelected: state.selectedSpec?.id == spec.id
                                    ) {
                                        state.selectedSpec = spec
                                        if !state.availableVariants.contains(state.selectedVariant) {
                                            state.selectedVariant = state.availableVariants.first ?? .vfOnly
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 8)
                .padding(.trailing, 6)
            }

            confidenceLegend
        }
        .sheet(isPresented: $showingSpecSheet) {
            if let spec = state.selectedSpec {
                SpecDetailView(spec: spec)
                    .environment(state)
            }
        }
    }

    private var confidenceLegend: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider().opacity(0.5)
            HStack(spacing: 10) {
                legendItem(systemImage: "checkmark.seal.fill",
                           color: Brand.accentMint,
                           label: SpecConfidence.verified.localizedLabel(state.locale))
                legendItem(systemImage: "doc.badge.gearshape.fill",
                           color: Brand.accentBlue,
                           label: SpecConfidence.standard.localizedLabel(state.locale))
                legendItem(systemImage: "exclamationmark.triangle.fill",
                           color: Brand.accentPeach,
                           label: SpecConfidence.generic.localizedLabel(state.locale))
            }
            .padding(.horizontal, 4)
            .padding(.top, 6)
            .padding(.bottom, 2)
        }
    }

    private func legendItem(systemImage: String, color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Right column

    private var rightColumn: some View {
        @Bindable var state = state
        return VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: state.t(.sectionVariant), icon: "speaker.wave.2.bubble")
                    VariantPillBar(
                        variants: state.availableVariants,
                        selection: $state.selectedVariant
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: state.t(.sectionFile), icon: "doc.fill")
                    CompactDropZone()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            ToleranceCard()

            statsStrip
            actionButtons

            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(
                    title: state.t(.sectionReport),
                    icon: "list.bullet.rectangle",
                    trailing: state.lastReport.map { _ in
                        AnyView(HStack(spacing: 8) { verdictPill })
                    }
                )
                ResultsPanelView()
                    .frame(maxHeight: .infinity)
            }

            bottomBar
        }
    }

    private var statsStrip: some View {
        HStack(spacing: 12) {
            StatCard(label: state.t(.statFound),
                     value: "\(state.lastReport?.checks.count ?? 0)",
                     icon: "magnifyingglass",
                     tintBackground: Brand.tintBlue,
                     accent: Brand.accentBlue)
            StatCard(label: state.t(.statPass),
                     value: "\(state.lastReport?.passCount ?? 0)",
                     icon: "checkmark.seal.fill",
                     tintBackground: Brand.tintMint,
                     accent: Brand.accentMint)
            StatCard(label: state.t(.statWarn),
                     value: "\(state.lastReport?.warningCount ?? 0)",
                     icon: "exclamationmark.triangle.fill",
                     tintBackground: Brand.tintPeach,
                     accent: Brand.accentPeach)
            StatCard(label: state.t(.statFail),
                     value: "\(state.lastReport?.failCount ?? 0)",
                     icon: "xmark.octagon.fill",
                     tintBackground: Brand.tintRed,
                     accent: Brand.accentRed)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button {
                Task { await launchAnalysis() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text(state.t(.actionLaunch))
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: launchEnabled
                            ? [Brand.gradientStart, Brand.gradientMid, Brand.gradientEnd]
                            : [Color.secondary.opacity(0.25), Color.secondary.opacity(0.25)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(launchEnabled ? Color.white : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!launchEnabled)

            Button {
                state.reset()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.uturn.backward")
                    Text(state.t(.actionReset))
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(nsColor: .windowBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var launchEnabled: Bool {
        state.droppedFile != nil && state.selectedSpec != nil && !state.isAnalyzing
    }

    private var verdictPill: some View {
        let v = state.lastReport!.verdict
        let label: String
        switch v {
        case .pass: label = state.t(.verdictPass)
        case .warning: label = state.t(.verdictWarn)
        case .fail: label = state.t(.verdictFail)
        }
        return StatusPill(
            label: label,
            icon: v.symbolName,
            tint: v == .pass ? Brand.accentMint : v == .warning ? Brand.accentPeach : .red
        )
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            bottomBarButton(label: state.t(.actionClear), icon: "trash",
                            action: state.reset, enabled: state.lastReport != nil)
            bottomBarButton(label: state.t(.actionExportPDF), icon: "square.and.arrow.down",
                            action: exportPDF, enabled: state.lastReport != nil)
            bottomBarButton(label: state.t(.actionExportCSV), icon: "tablecells",
                            action: exportCSV, enabled: state.lastReport != nil)
            bottomBarButton(label: state.t(.actionExportRemediation),
                            icon: "wrench.and.screwdriver",
                            action: exportRemediation,
                            enabled: hasFailingChecks)
            bottomBarButton(label: state.t(.actionRevealFile), icon: "folder",
                            action: revealInFinder, enabled: state.droppedFile != nil)
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }

    private func bottomBarButton(label: String, icon: String,
                                 action: @escaping () -> Void, enabled: Bool) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                Text(label).font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(enabled
                             ? Color(nsColor: NSColor(white: 0.15, alpha: 1))
                             : Color(nsColor: NSColor(white: 0.55, alpha: 1)))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func launchAnalysis() async {
        guard let url = state.droppedFile else { return }
        await state.analyze(file: url)
    }

    private func exportPDF() {
        guard let report = state.lastReport else { return }
        guard state.license.status.allowsExports else {
            state.errorMessage = state.t(.licenseRestrictExports)
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "MisiQC-Pro-\(report.fileURL.deletingPathExtension().lastPathComponent).pdf"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try PDFReportRenderer.write(report, to: url,
                                            license: state.license)
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch {
                state.errorMessage = error.localizedDescription
            }
        }
    }

    private func exportCSV() {
        guard let report = state.lastReport else { return }
        guard state.license.status.allowsExports else {
            state.errorMessage = state.t(.licenseRestrictExports)
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.commaSeparatedText]
        panel.nameFieldStringValue =
            "MisiQC-Pro-\(report.fileURL.deletingPathExtension().lastPathComponent).csv"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try CSVExporter.write(report, to: url)
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch {
                state.errorMessage = error.localizedDescription
            }
        }
    }

    private var hasFailingChecks: Bool {
        guard let report = state.lastReport else { return false }
        return report.checks.contains { $0.status != .pass }
    }

    private func exportRemediation() {
        guard let report = state.lastReport else { return }
        guard state.license.status.allowsExports else {
            state.errorMessage = state.t(.licenseRestrictExports)
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue =
            "MisiQC-Pro-\(report.fileURL.deletingPathExtension().lastPathComponent)-correction.pdf"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try RemediationPDFRenderer.write(report, to: url)
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch {
                state.errorMessage = error.localizedDescription
            }
        }
    }

    private func revealInFinder() {
        guard let url = state.droppedFile else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .frame(width: 1500, height: 1020)
}
