#if os(iOS)
import AuthenticationServices
import UIKit

@MainActor
enum ConnectorWebAuthenticationFactory {
    static func make() -> any ConnectorWebAuthenticating {
        ConnectorWebAuthentication {
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                .filter { $0.activationState == .foregroundActive }
                .flatMap(\.windows).first(where: \.isKeyWindow) ?? ASPresentationAnchor()
        }
    }
}
#endif
