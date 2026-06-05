import SwiftUI
import UniformTypeIdentifiers

/// Slim drop zone used inside the left config column. Shows the dropped file
/// when set, otherwise an empty "Glissez un master" state with a Choisir button.
struct CompactDropZone: View {
    @Environment(AppState.self) private var state
    @State private var isTargeted = false

    var body: some View {
        HStack(spacing: 12) {
            iconTile
            VStack(alignment: .leading, spacing: 2) {
                Text(state.droppedFile?.lastPathComponent ?? state.t(.dropEmpty))
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text({
                    if let file = state.droppedFile {
                        return sizeString(of: file)
                    }
                    return state.t(.dropHint)
                }())
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button {
                openPanel()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "folder.fill.badge.plus")
                    Text(state.t(.dropChoose))
                }
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color(nsColor: .controlBackgroundColor)))
                .overlay(Capsule().strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: isTargeted ? 2 : 1,
                                                 dash: isTargeted ? [] : [4, 3]))
                .foregroundStyle(isTargeted ? Brand.accentBlue : Color.secondary.opacity(0.4))
        )
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
    }

    private var iconTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(state.droppedFile == nil
                      ? Color.secondary.opacity(0.12)
                      : Brand.accentBlue.opacity(0.18))
            Image(systemName: state.droppedFile == nil ? "questionmark.video" : "film.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(state.droppedFile == nil ? .secondary : Brand.accentBlue)
        }
        .frame(width: 32, height: 32)
    }

    private func sizeString(of url: URL) -> String {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let bytes = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
        let bcf = ByteCountFormatter()
        bcf.allowedUnits = [.useGB, .useMB]
        bcf.countStyle = .file
        return bcf.string(fromByteCount: bytes)
    }

    private func openPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = supportedTypes
        if panel.runModal() == .OK, let url = panel.url {
            state.droppedFile = url
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url else { return }
            Task { @MainActor in
                state.droppedFile = url
            }
        }
        return true
    }

    private var supportedTypes: [UTType] {
        var types: [UTType] = [.movie, .audiovisualContent, .video, .mpeg4Movie, .quickTimeMovie]
        if let mxf = UTType("org.smpte.mxf") { types.append(mxf) }
        return types
    }
}
