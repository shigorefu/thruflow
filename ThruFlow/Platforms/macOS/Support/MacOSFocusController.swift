#if os(macOS)
import AppKit

enum MacOSFocusController {
    static func dismissCurrentTextEditor() {
        guard let window = NSApp.keyWindow, window.firstResponder is NSTextView else { return }
        window.makeFirstResponder(nil)
    }

    static func dismissCurrentEditor() {
        NSApp.keyWindow?.makeFirstResponder(nil)
    }
}
#endif
