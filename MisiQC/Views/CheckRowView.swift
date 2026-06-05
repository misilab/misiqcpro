import SwiftUI

struct CheckRowView: View {
    let check: Check

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: check.status.symbolName)
                .foregroundStyle(color)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 22)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(check.label)
                    .font(.callout)
                    .fontWeight(.medium)
                HStack(spacing: 14) {
                    Label(check.expected, systemImage: "target")
                        .foregroundStyle(.secondary)
                    Label(check.actual, systemImage: "waveform.path.ecg")
                        .foregroundStyle(color)
                        .fontWeight(.semibold)
                }
                .font(.caption)
                .labelStyle(.titleAndIcon)
                if let detail = check.detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private var color: Color {
        switch check.status {
        case .pass: return .green
        case .warning: return .orange
        case .fail: return .red
        }
    }
}
