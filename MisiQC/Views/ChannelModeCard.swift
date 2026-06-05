import SwiftUI

/// Selectable channel profile card — single-line, compact (≈ 40pt tall) so a
/// long list of channels fits without much scrolling.
struct ChannelModeCard: View {
    @Environment(AppState.self) private var state
    let spec: ChannelSpec
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                iconTile
                Text(spec.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                confidenceBadge
                Spacer(minLength: 6)
                radio
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(background)
            .overlay(border)
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(spec.confidence == .generic ? state.t(.tipConfGeneric) :
              spec.confidence == .standard ? state.t(.tipConfStandard) :
              state.t(.tipConfVerified))
    }

    @ViewBuilder private var confidenceBadge: some View {
        switch spec.confidence {
        case .verified:
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(red: 0.118, green: 0.682, blue: 0.408))
        case .standard:
            Image(systemName: "doc.badge.gearshape.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(red: 0.180, green: 0.475, blue: 0.960))
        case .generic:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color(red: 0.937, green: 0.510, blue: 0.114))
        }
    }

    private var accent: Color { .channel(spec.id) }

    private var iconTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(accent.opacity(0.18))
            Image(systemName: "tv")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(accent)
        }
        .frame(width: 22, height: 22)
    }

    private var radio: some View {
        ZStack {
            Circle()
                .strokeBorder(isSelected ? accent : Color.secondary.opacity(0.45), lineWidth: 1.3)
                .frame(width: 14, height: 14)
            if isSelected {
                Circle().fill(accent).frame(width: 8, height: 8)
            }
        }
    }

    @ViewBuilder private var background: some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(isSelected ? accent.opacity(0.12) : Color(nsColor: .controlBackgroundColor))
    }

    @ViewBuilder private var border: some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .strokeBorder(isSelected ? accent.opacity(0.55) : Color.secondary.opacity(0.18),
                          lineWidth: isSelected ? 1.3 : 0.8)
    }
}
