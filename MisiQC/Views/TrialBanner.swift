import SwiftUI

/// Top-of-window banner that appears while the trial is still running (or has
/// expired). Hidden when the app is licensed.
struct TrialBanner: View {
    @Environment(AppState.self) private var state
    @Environment(\.openURL) private var openURL

    /// Public Payhip purchase page — overwrite when the product is live.
    private let purchaseURL = URL(string: "https://payhip.com/b/NqSMZ")!

    var body: some View {
        switch state.license.status {
        case .licensed:
            EmptyView()
        case .trial(let days):
            banner(text: trialText(days: days),
                   accent: days <= 2 ? Brand.accentPeach : Brand.accentBlue,
                   icon: "clock.fill")
        case .expired:
            banner(text: state.t(.licenseTrialBannerExpired),
                   accent: Color(red: 0.85, green: 0.20, blue: 0.20),
                   icon: "exclamationmark.octagon.fill")
        }
    }

    private func trialText(days: Int) -> String {
        if days == 0 { return state.t(.licenseLastDay) }
        return String(format: state.t(.licenseTrialBanner), days)
    }

    private func banner(text: String, accent: Color, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(accent)
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
            Spacer(minLength: 6)
            Button {
                openURL(purchaseURL)
            } label: {
                Text(state.t(.licenseBuyButton))
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(accent))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Rectangle()
                .fill(accent.opacity(0.10))
        )
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(accent.opacity(0.3)),
            alignment: .bottom
        )
    }
}
