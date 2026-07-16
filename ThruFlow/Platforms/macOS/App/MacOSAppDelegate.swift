#if os(macOS)
import AppKit

final class MacOSAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
              let icon = NSImage(contentsOf: iconURL) else { return }

        NSApplication.shared.applicationIconImage = icon
    }
}
#endif
