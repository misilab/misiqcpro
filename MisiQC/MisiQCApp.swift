import SwiftUI
import AppKit
import UniformTypeIdentifiers

@main
struct MisiQCApp: App {
    @State private var appState = AppState()
    @State private var updater = UpdateService()

    init() {
        // Force the menu-bar app name without touching CFBundleName in
        // Build Settings. macOS reads the first menu item's title for the
        // bold app-name label at the top of the menu bar.
        DispatchQueue.main.async {
            NSApp.mainMenu?.items.first?.title = "MisiQC Pro"
        }
    }

    var body: some Scene {
        WindowGroup("MisiQC Pro") {
            ContentView()
                .environment(appState)
                .frame(minWidth: 1500, idealWidth: 1500, minHeight: 1020, idealHeight: 1020)
                .navigationTitle("MisiQC Pro")
                .onAppear { updater.scheduleAutoCheckAfterLaunch() }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .windowResizability(.contentSize)
        .commands {
            // Replace the default "New" item — we don't have documents.
            CommandGroup(replacing: .newItem) { }

            // App menu additions.
            CommandGroup(replacing: .appInfo) {
                Button("\(appState.t(.settingsAbout)) MisiQC Pro") {
                    NSApp.orderFrontStandardAboutPanel(nil)
                }
                Button(appState.t(.menuCheckUpdates)) {
                    updater.checkForUpdates()
                }
            }

            // File menu.
            CommandGroup(after: .newItem) {
                Button(appState.t(.menuOpenFile)) { openFilePanel() }
                    .keyboardShortcut("o", modifiers: .command)

                Divider()

                Button(appState.t(.actionLaunch)) {
                    Task { await launchAnalysis() }
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(appState.droppedFile == nil || appState.isAnalyzing)

                Button(appState.t(.actionExportPDF)) { exportPDF() }
                    .keyboardShortcut("e", modifiers: .command)
                    .disabled(appState.lastReport == nil)

                Button(appState.t(.actionExportCSV)) { exportCSV() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                    .disabled(appState.lastReport == nil)

                Divider()

                Button(appState.t(.actionReset)) { appState.reset() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])

                Button(appState.t(.actionRevealFile)) { revealInFinder() }
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(appState.droppedFile == nil)
            }

            // Channel profile sub-menu. Only the first 9 channels get a Cmd+digit
            // shortcut — single-digit Characters only.
            CommandMenu(appState.t(.menuProfile)) {
                ForEach(Array(appState.availableSpecs.enumerated()), id: \.element.id) { idx, spec in
                    let button = Button(spec.name) {
                        appState.selectedSpec = spec
                        if !appState.availableVariants.contains(appState.selectedVariant) {
                            appState.selectedVariant = appState.availableVariants.first ?? .vfOnly
                        }
                    }
                    if idx < 9 {
                        button.keyboardShortcut(
                            KeyEquivalent(Character("\(idx + 1)")), modifiers: .command)
                    } else {
                        button
                    }
                }
            }

            // Audio variant sub-menu (Cmd+Alt+1…4).
            CommandMenu(appState.t(.menuVariant)) {
                ForEach(Array(VersionVariant.allCases.enumerated()), id: \.element) { idx, variant in
                    Button(variant.displayString) {
                        if appState.availableVariants.contains(variant) {
                            appState.selectedVariant = variant
                        }
                    }
                    .disabled(!appState.availableVariants.contains(variant))
                    .keyboardShortcut(KeyEquivalent(Character("\(idx + 1)")),
                                      modifiers: [.command, .option])
                }
            }

            // Language quick-switch (Cmd+Shift+L cycles).
            CommandMenu(appState.t(.settingsLanguage)) {
                ForEach(AppLocale.allCases) { locale in
                    Button("\(locale.flagEmoji) \(locale.displayName)") {
                        appState.locale = locale
                    }
                }
            }
        }

        Settings {
            SettingsView()
                .environment(appState)
        }
    }

    // MARK: - Menu actions

    private func openFilePanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        var types: [UTType] = [.movie, .audiovisualContent, .video, .mpeg4Movie, .quickTimeMovie]
        if let mxf = UTType("org.smpte.mxf") { types.append(mxf) }
        panel.allowedContentTypes = types
        if panel.runModal() == .OK, let url = panel.url {
            appState.droppedFile = url
        }
    }

    private func launchAnalysis() async {
        guard let url = appState.droppedFile else { return }
        await appState.analyze(file: url)
    }

    private func exportPDF() {
        guard let report = appState.lastReport else { return }
        guard appState.license.status.allowsExports else {
            appState.errorMessage = appState.t(.licenseRestrictExports)
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue =
            "MisiQC-Pro-\(report.fileURL.deletingPathExtension().lastPathComponent).pdf"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try PDFReportRenderer.write(report, to: url,
                                            license: appState.license)
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch {
                appState.errorMessage = error.localizedDescription
            }
        }
    }

    private func exportCSV() {
        guard let report = appState.lastReport else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.commaSeparatedText]
        panel.nameFieldStringValue =
            "MisiQC-Pro-\(report.fileURL.deletingPathExtension().lastPathComponent).csv"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try CSVExporter.write(report, to: url)
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch {
                appState.errorMessage = error.localizedDescription
            }
        }
    }

    private func revealInFinder() {
        guard let url = appState.droppedFile else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
