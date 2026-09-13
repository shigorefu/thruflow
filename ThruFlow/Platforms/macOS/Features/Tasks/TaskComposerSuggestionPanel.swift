#if os(macOS)
import AppKit
import SwiftUI

/// A non-activating child panel allows typing to continue in the composer,
/// including when the composer itself lives in a popover or menu-bar window.
struct TaskComposerSuggestionPanel<Content: View>: NSViewRepresentable {
    let isPresented: Bool
    var showsBelow = false
    @ViewBuilder let content: () -> Content

    func makeNSView(context: Context) -> AnchorView { AnchorView() }

    func updateNSView(_ view: AnchorView, context: Context) {
        view.update(content: AnyView(content()), isPresented: isPresented, showsBelow: showsBelow)
    }

    static func dismantleNSView(_ view: AnchorView, coordinator: ()) {
        view.dismiss()
    }

    final class AnchorView: NSView {
        private var panel: NSPanel?
        private var hostingView: NSHostingView<AnyView>?
        private var observers: [NSObjectProtocol] = []
        private var content = AnyView(EmptyView())
        private var isPresented = false
        private var showsBelow = false

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            dismiss()
            guard let window else { return }
            for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification] {
                observers.append(NotificationCenter.default.addObserver(
                    forName: name, object: window, queue: .main
                ) { [weak self] _ in
                    MainActor.assumeIsolated { self?.positionPanel() }
                })
            }
            refresh()
        }

        override func layout() {
            super.layout()
            positionPanel()
        }

        func update(content: AnyView, isPresented: Bool, showsBelow: Bool = false) {
            self.content = content
            self.isPresented = isPresented
            self.showsBelow = showsBelow
            refresh()
        }

        private func refresh() {
            guard isPresented, let window else {
                dismissPanel()
                return
            }
            if panel == nil {
                let panel = SuggestionPanel(
                    contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                    backing: .buffered, defer: false
                )
                panel.isOpaque = false
                panel.backgroundColor = .clear
                panel.hasShadow = true
                panel.isReleasedWhenClosed = false
                panel.hidesOnDeactivate = true
                let hosting = NSHostingView(rootView: content)
                panel.contentView = hosting
                self.panel = panel
                hostingView = hosting
                window.addChildWindow(panel, ordered: .above)
            }
            hostingView?.rootView = content
            positionPanel()
            panel?.orderFront(nil)
        }

        private func positionPanel() {
            guard let window, let panel, let hostingView else { return }
            let size = hostingView.fittingSize
            let anchor = window.convertToScreen(convert(bounds, to: nil))
            let screen = window.screen?.visibleFrame ?? anchor
            let x = min(max(anchor.minX, screen.minX), max(screen.minX, screen.maxX - size.width))
            let above = anchor.maxY + 8
            let below = anchor.minY - size.height - 8
            let preferred = showsBelow ? below : above
            let alternative = showsBelow ? above : below
            let fits = preferred >= screen.minY && preferred + size.height <= screen.maxY
            let y = min(max(fits ? preferred : alternative, screen.minY), screen.maxY - size.height)
            panel.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: size), display: true)
        }

        private func dismissPanel() {
            if let panel { panel.parent?.removeChildWindow(panel); panel.orderOut(nil) }
            panel = nil
            hostingView = nil
        }

        func dismiss() {
            dismissPanel()
            observers.forEach(NotificationCenter.default.removeObserver)
            observers.removeAll()
        }
    }
}

private final class SuggestionPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
#endif
