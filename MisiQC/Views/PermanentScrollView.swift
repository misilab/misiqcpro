import SwiftUI
import AppKit

/// macOS-only ScrollView wrapper that **forces** the vertical scroller to be
/// permanently visible — bypasses the system pref "Show scroll bars: When
/// scrolling / Always". Uses `NSScroller.legacy` style (= solid bar that
/// reserves space, instead of the overlay style that fades out).
struct PermanentScrollView<Content: View>: NSViewRepresentable {

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.scrollerStyle = .legacy                       // always-visible
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = false
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.verticalScrollElasticity = .allowed

        let hosting = NSHostingView(rootView: content)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = hosting

        // Lock the content width to the clip-view width minus the scroller
        // gutter, so the inner SwiftUI layout never reflows horizontally.
        let clip = scroll.contentView
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: clip.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: clip.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: clip.topAnchor)
        ])
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let hosting = nsView.documentView as? NSHostingView<Content> else { return }
        hosting.rootView = content
        // Re-evaluate intrinsic size when content changes.
        hosting.invalidateIntrinsicContentSize()
    }
}
