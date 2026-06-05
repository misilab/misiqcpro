import SwiftUI

/// Rounded-square brand logo: vibrant acidulé gradient with a continuous white
/// stroke that starts as an audio waveform on the left and resolves into a
/// bold checkmark on the right — signal verified.
struct BrandLogo: View {
    var size: CGFloat = 48

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                .fill(LinearGradient(
                    colors: [Brand.gradientStart, Brand.gradientMid, Brand.gradientEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                        .fill(LinearGradient(
                            colors: [Color.white.opacity(0.32), .clear],
                            startPoint: .top,
                            endPoint: .center
                        ))
                        .blendMode(.softLight)
                )

            wavePath
                .stroke(Color.white,
                        style: StrokeStyle(lineWidth: size * 0.105,
                                           lineCap: .round, lineJoin: .round))
                .shadow(color: .black.opacity(0.15), radius: size * 0.02, y: size * 0.01)
        }
        .frame(width: size, height: size)
    }

    private var wavePath: Path {
        Path { p in
            let amp = size * 0.085
            let yMid = size * 0.50

            // Waveform — three soft oscillations on the left third
            p.move(to: CGPoint(x: size * 0.12, y: yMid))
            p.addQuadCurve(
                to:      CGPoint(x: size * 0.22, y: yMid),
                control: CGPoint(x: size * 0.17, y: yMid - amp)
            )
            p.addQuadCurve(
                to:      CGPoint(x: size * 0.32, y: yMid),
                control: CGPoint(x: size * 0.27, y: yMid + amp)
            )
            p.addQuadCurve(
                to:      CGPoint(x: size * 0.42, y: yMid),
                control: CGPoint(x: size * 0.37, y: yMid - amp)
            )
            // Resolve into the checkmark — pivot then long upstroke
            p.addLine(to: CGPoint(x: size * 0.53, y: size * 0.72))
            p.addLine(to: CGPoint(x: size * 0.86, y: size * 0.28))
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        BrandLogo(size: 256)
        BrandLogo(size: 128)
        BrandLogo(size: 64)
        BrandLogo(size: 32)
    }
    .padding(40)
    .background(Color.white)
}
