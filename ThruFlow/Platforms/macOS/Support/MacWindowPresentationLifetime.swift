#if os(macOS)
import AppKit
import SwiftUI

/// Window-style MenuBarExtra retains its view when ordered out. Follow the
/// actual host window rather than treating SwiftUI disappearance or key focus
/// as proof that an owned presentation must close.
@MainActor
final class MacWindowPresentationLifetime {
    private var observations: [NSKeyValueObservation] = []
    private var notifications: [NSObjectProtocol] = []

    init(window: NSWindow, onHidden: @escaping @MainActor () -> Void) {
        observations.append(window.observe(\.isVisible, options: [.new]) { window, _ in
            MainActor.assumeIsolated {
                if !window.isVisible { onHidden() }
            }
        })
        observations.append(window.observe(\.isMiniaturized, options: [.new]) { window, _ in
            MainActor.assumeIsolated {
                if window.isMiniaturized { onHidden() }
            }
        })
        for (name, object) in [
            (NSWindow.willCloseNotification, window as AnyObject),
            (NSApplication.didHideNotification, NSApp as AnyObject)
        ] {
            notifications.append(NotificationCenter.default.addObserver(
                forName: name, object: object, queue: .main
            ) { _ in
                MainActor.assumeIsolated { onHidden() }
            })
        }
    }

    func invalidate() {
        observations.forEach { $0.invalidate() }
        observations.removeAll()
        notifications.forEach(NotificationCenter.default.removeObserver)
        notifications.removeAll()
    }
}

struct MacWindowPresentationAnchor: NSViewRepresentable {
    let onHidden: () -> Void

    func makeNSView(context: Context) -> MacWindowPresentationAnchorView {
        let view = MacWindowPresentationAnchorView()
        view.onHidden = onHidden
        return view
    }

    func updateNSView(_ view: MacWindowPresentationAnchorView, context: Context) {
        view.onHidden = onHidden
    }

    static func dismantleNSView(_ view: MacWindowPresentationAnchorView, coordinator: ()) {
        view.invalidate()
    }
}

final class MacWindowPresentationAnchorView: NSView {
    var onHidden: () -> Void = {}
    private var lifetime: MacWindowPresentationLifetime?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        invalidate()
        if let window {
            lifetime = MacWindowPresentationLifetime(window: window) { [weak self] in
                self?.onHidden()
            }
        }
    }

    func invalidate() {
        lifetime?.invalidate()
        lifetime = nil
    }
}
#endif
