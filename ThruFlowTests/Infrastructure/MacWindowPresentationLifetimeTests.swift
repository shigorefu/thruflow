import AppKit
import SwiftUI
import Testing
@testable import ThruFlow

@Suite(.serialized) @MainActor
struct MacWindowPresentationLifetimeTests {
    @Test func orderingOutRetainedHostDismissesOwnedPresentation() {
        let window = makeWindow()
        var isPresented = true
        let lifetime = MacWindowPresentationLifetime(window: window) { isPresented = false }
        defer { lifetime.invalidate(); window.close() }

        window.orderFront(nil)
        #expect(isPresented)
        // The MenuBarExtra content can remain mounted after orderOut.
        window.orderOut(nil)
        #expect(!isPresented)
        window.orderFront(nil)
        #expect(!isPresented)
    }

    @Test func childFocusDoesNotDismissButAppHideDoes() {
        let window = makeWindow()
        var isPresented = true
        let lifetime = MacWindowPresentationLifetime(window: window) { isPresented = false }
        defer { lifetime.invalidate(); window.close() }
        window.orderFront(nil)
        NotificationCenter.default.post(name: NSWindow.didResignKeyNotification, object: window)
        #expect(isPresented)
        NotificationCenter.default.post(name: NSApplication.didHideNotification, object: NSApp)
        #expect(!isPresented)
    }

    @Test func minimizingHostDismissesOwnedPresentation() async throws {
        let window = makeWindow()
        var isPresented = true
        let lifetime = MacWindowPresentationLifetime(window: window) { isPresented = false }
        defer { lifetime.invalidate(); window.close() }
        window.orderFront(nil)
        window.miniaturize(nil)
        for _ in 0..<20 where isPresented {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(window.isMiniaturized)
        #expect(!isPresented)
    }

    @Test func closingHostDismissesButInvalidatedObserverDoesNotFire() {
        let window = makeWindow()
        var calls = 0
        let lifetime = MacWindowPresentationLifetime(window: window) { calls += 1 }
        window.orderFront(nil)
        window.close()
        #expect(calls > 0)
        lifetime.invalidate()
        let previous = calls
        NotificationCenter.default.post(name: NSApplication.didHideNotification, object: NSApp)
        #expect(calls == previous)
    }

    @Test func hiddenHostCannotReopenSuggestionPanelDuringViewUpdates() {
        let window = makeWindow()
        let anchor = TaskComposerSuggestionAnchorView(frame: NSRect(x: 0, y: 0, width: 100, height: 20))
        window.contentView = anchor
        defer { anchor.dismiss(); window.close() }
        window.orderFront(nil)
        anchor.update(content: AnyView(Text("Suggestion")), isPresented: true)
        #expect(window.childWindows?.count == 1)
        window.orderOut(nil)
        #expect(window.childWindows?.isEmpty != false)
        anchor.update(content: AnyView(Text("Suggestion")), isPresented: true)
        #expect(window.childWindows?.isEmpty != false)
    }

    @Test func swiftUIAnchorObservesItsActualHost() async throws {
        let window = makeWindow()
        var isPresented = true
        window.contentView = NSHostingView(rootView:
            Color.clear.background(MacWindowPresentationAnchor { isPresented = false })
        )
        defer { window.close() }
        window.orderFront(nil)
        try await Task.sleep(for: .milliseconds(100))
        #expect(isPresented)
        window.orderOut(nil)
        #expect(!isPresented)
    }

    @Test func actualApplicationHideDismissesOwnedPresentation() async throws {
        let app = NSApplication.shared
        let window = makeWindow()
        var isPresented = true
        let lifetime = MacWindowPresentationLifetime(window: window) { isPresented = false }
        defer { lifetime.invalidate(); app.unhideWithoutActivation(); window.close() }
        window.orderFront(nil)
        app.hide(nil)
        for _ in 0..<20 where isPresented {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(app.isHidden)
        #expect(!isPresented)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 40, y: 40, width: 160, height: 120),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        return window
    }
}
