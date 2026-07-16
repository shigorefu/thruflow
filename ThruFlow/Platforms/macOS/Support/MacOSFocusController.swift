#if os(macOS)
import AppKit

enum MacOSFocusController {
    static func dismissCurrentEditor() {
        NSApp.keyWindow?.makeFirstResponder(nil)
    }
}
#endif
