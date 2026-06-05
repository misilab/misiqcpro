import SwiftUI

/// Pastel stat card (e.g. "CONFORMES — 0"). Used in the right-column header strip.
struct StatCard: View {
    let label: String
    let value: String
    let icon: String
    let tintBackground: Color
    let accent: Color

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(label.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.6)
            }
            .foregroundStyle(accent)

            Text(value)
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(.primary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, minHeight: 78)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tintBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(accent.opacity(0.18), lineWidth: 1)
        )
    }
}
