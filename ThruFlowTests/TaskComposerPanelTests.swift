#if os(macOS)
import AppKit
import SwiftUI
import Testing
@testable import ThruFlow

@MainActor struct TaskComposerPanelTests {
    @Test(arguments: [false, true])
    func panelRespectsPreferredSideWithoutTakingKeyboardFocusAndIsRemoved(showsBelow: Bool) throws {
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 400, height: 90),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let anchor = TaskComposerSuggestionPanel<Text>.AnchorView(frame: NSRect(x: 0, y: 0, width: 400, height: 90))
        window.contentView = anchor
        let originalFrame = window.frame
        anchor.update(content: AnyView(Text("Suggestion").padding().frame(width: 320)), isPresented: true, showsBelow: showsBelow)
        let panel = try #require(window.childWindows?.first)
        #expect(!panel.canBecomeKey)
        #expect(window.frame == originalFrame)
        if showsBelow {
            #expect(panel.frame.maxY <= window.frame.minY)
        } else {
            #expect(panel.frame.minY >= window.frame.maxY)
        }
        #expect(panel.frame.width == 320)
        anchor.update(content: AnyView(EmptyView()), isPresented: false)
        #expect(window.childWindows?.isEmpty != false)
        anchor.dismiss()
    }
}
#endif
