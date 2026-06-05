import SwiftUI

/// Small uppercase grey label used to header a config section.
struct SectionHeader: View {
    let title: String
    var icon: String?
    var trailing: AnyView? = nil

    var body: some View {
        HStack(spacing: 8) {
            if let icon { Image(systemName: icon).foregroundStyle(.secondary) }
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            if let trailing { trailing }
        }
        .padding(.bottom, 4)
    }
}

/// Rounded pill badge used in the header (LICENCE, version, etc.).
struct StatusPill: View {
    let label: String
    var icon: String?
    var tint: Color = Brand.accentMint

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
            }
            Text(label)
                .font(.system(size: 10, weight: .heavy))
                .tracking(0.5)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(tint.opacity(0.16))
        )
        .overlay(
            Capsule().strokeBorder(tint.opacity(0.35), lineWidth: 0.5)
        )
    }
}

/// Subtle "made by" footer line shown at the very bottom of the window.
struct FooterCredit: View {
    var body: some View {
        HStack(spacing: 4) {
            Text("MisiQC Pro créé par Matthieu Misiraca —")
            Link("www.misiraca.com", destination: URL(string: "https://www.misiraca.com")!)
                .foregroundStyle(Brand.accentBlue)
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.vertical, 10)
    }
}
