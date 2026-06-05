import SwiftUI

/// Inline tolerance picker shown directly in the main window, so the user can
/// switch broadcast strictness without opening Settings. Mirrors the section in
/// SettingsView but in a compact card.
struct ToleranceCard: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: state.t(.settingsToleranceSection),
                          icon: "slider.horizontal.3")
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Text(state.t(.settingsToleranceLevel))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Picker("", selection: $state.signalStrictness) {
                        ForEach(SignalStrictness.allCases) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                }
                Text(state.signalStrictness.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.18), lineWidth: 1)
            )
        }
    }
}
