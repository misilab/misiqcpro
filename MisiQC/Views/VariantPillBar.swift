import SwiftUI

/// Row of pastel pill buttons letting the user pick the audio version variant.
/// Each pill rotates through a soft palette to feel "acidulé".
struct VariantPillBar: View {
    let variants: [VersionVariant]
    @Binding var selection: VersionVariant

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(variants.enumerated()), id: \.element) { idx, v in
                pill(for: v, color: tint(for: idx))
            }
        }
    }

    private func tint(for index: Int) -> (bg: Color, fg: Color) {
        let palette: [(Color, Color)] = [
            (Brand.tintPeach, Brand.accentPeach),
            (Brand.tintLilac, Brand.accentLilac),
            (Brand.tintBlue, Brand.accentBlue),
            (Brand.tintMint, Brand.accentMint)
        ]
        return palette[index % palette.count]
    }

    private func pill(for variant: VersionVariant, color: (bg: Color, fg: Color)) -> some View {
        Button {
            selection = variant
        } label: {
            HStack(spacing: 5) {
                Image(systemName: iconName(for: variant))
                    .font(.system(size: 11, weight: .bold))
                Text(variant.displayString)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(color.fg)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                Capsule()
                    .fill(selection == variant ? color.bg : Color.secondary.opacity(0.08))
            )
            .overlay(
                Capsule()
                    .strokeBorder(selection == variant ? color.fg.opacity(0.45) : Color.clear,
                                  lineWidth: 1.2)
            )
        }
        .buttonStyle(.plain)
    }

    private func iconName(for variant: VersionVariant) -> String {
        switch variant {
        case .vfOnly: return "speaker.wave.2"
        case .vfVO:  return "globe"
        case .vfAD:  return "ear"
        case .vfVOAD: return "person.2.wave.2"
        }
    }
}
