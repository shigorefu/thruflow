#if os(macOS)
import AppKit
import AuthenticationServices

@MainActor
enum ConnectorWebAuthenticationFactory {
    static func make() -> any ConnectorWebAuthenticating {
        ConnectorWebAuthentication { NSApp.keyWindow ?? NSApp.mainWindow ?? ASPresentationAnchor() }
    }
}
#endif
