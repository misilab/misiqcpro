import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        TabView {
            generalTab(state: $state)
                .tabItem { Label(state.t(.settingsTitle), systemImage: "gear") }
            detectionTab(state: $state)
                .tabItem { Label(state.t(.settingsDetection), systemImage: "waveform.path.ecg") }
            LicenseSettingsView()
                .tabItem { Label(state.t(.licenseSettingsTab), systemImage: "key.fill") }
            aboutTab
                .tabItem { Label(state.t(.settingsAbout), systemImage: "info.circle") }
        }
        .frame(width: 520, height: 420)
    }

    // MARK: - General

    private func generalTab(state: Bindable<AppState>) -> some View {
        Form {
            Section {
                Picker(state.wrappedValue.t(.settingsLanguage), selection: state.locale) {
                    ForEach(AppLocale.allCases) { locale in
                        Text("\(locale.flagEmoji) \(locale.displayName)").tag(locale)
                    }
                }
                .pickerStyle(.menu)
                Text(state.wrappedValue.t(.settingsLanguageNote))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text(state.wrappedValue.t(.settingsLanguage))
            }

            Section {
                Picker(state.wrappedValue.t(.settingsDefaultProfile), selection: state.defaultProfileID) {
                    ForEach(state.wrappedValue.availableSpecs) { s in
                        Text(s.name).tag(s.id)
                    }
                }
                .pickerStyle(.menu)
                Picker(state.wrappedValue.t(.settingsDefaultVariant), selection: state.defaultVariant) {
                    ForEach(VersionVariant.allCases) { v in
                        Text(v.displayString).tag(v)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text(state.wrappedValue.t(.sectionChannel))
            }

            Section {
                Button(role: .destructive) {
                    state.wrappedValue.resetAllPreferences()
                } label: {
                    Label(state.wrappedValue.t(.settingsResetButton),
                          systemImage: "arrow.counterclockwise")
                }
                Text(state.wrappedValue.t(.settingsResetConfirm))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, 8)
    }

    // MARK: - Detection

    private func detectionTab(state: Bindable<AppState>) -> some View {
        Form {
            Section {
                LabeledContent(state.wrappedValue.t(.settingsBlackThreshold)) {
                    HStack {
                        Slider(value: state.blackThresholdSec, in: 0.2...10, step: 0.1)
                            .frame(maxWidth: 200)
                        Text(String(format: "%.1f s", state.wrappedValue.blackThresholdSec))
                            .monospacedDigit()
                            .frame(width: 56, alignment: .trailing)
                    }
                }
                LabeledContent(state.wrappedValue.t(.settingsSilenceThreshold)) {
                    HStack {
                        Slider(value: state.silenceThresholdSec, in: 0.2...30, step: 0.1)
                            .frame(maxWidth: 200)
                        Text(String(format: "%.1f s", state.wrappedValue.silenceThresholdSec))
                            .monospacedDigit()
                            .frame(width: 56, alignment: .trailing)
                    }
                }
            } header: {
                Text(state.wrappedValue.t(.settingsDetection))
            }

            Section {
                Picker(state.wrappedValue.t(.settingsToleranceLevel),
                       selection: state.signalStrictness) {
                    ForEach(SignalStrictness.allCases) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                .pickerStyle(.menu)
                Text(state.wrappedValue.signalStrictness.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text(state.wrappedValue.t(.settingsToleranceSection))
            } footer: {
                Text(state.wrappedValue.t(.settingsToleranceFooter))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

        }
        .formStyle(.grouped)
        .padding(.horizontal, 8)
    }

    // MARK: - About

    private var aboutTab: some View {
        VStack(spacing: 18) {
            BrandLogo(size: 96)
            Text("MisiQC Pro")
                .font(.system(size: 22, weight: .heavy))
            Text(state.t(.settingsAboutBody))
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                Text(state.t(.footerCredit))
                Link("www.misiraca.com",
                     destination: URL(string: "https://www.misiraca.com")!)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.bottom, 16)
        }
        .padding(.top, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
