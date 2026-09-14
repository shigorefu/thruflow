#if os(macOS) || os(iOS)
import AuthenticationServices
import Foundation

@MainActor
final class ConnectorWebAuthentication: NSObject, ConnectorWebAuthenticating, ASWebAuthenticationPresentationContextProviding {
    private let anchor: @MainActor () -> ASPresentationAnchor
    private var session: ASWebAuthenticationSession?
    private var activeAttempt: UUID?
    private var continuation: CheckedContinuation<URL, any Error>?

    init(anchor: @escaping @MainActor () -> ASPresentationAnchor) { self.anchor = anchor }

    func authenticate(url: URL) async throws -> URL {
        guard session == nil else { throw TodoistAuthorizationError.failed }
        try Task.checkCancellation()
        let attempt = UUID()
        activeAttempt = attempt
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                let completion: ASWebAuthenticationSession.CompletionHandler = { [weak self] url, error in
                    Task { @MainActor in
                        guard let self else { return }
                        if let url { self.finish(.success(url), attempt: attempt) }
                        else if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin {
                            self.finish(.failure(CancellationError()), attempt: attempt)
                        } else { self.finish(.failure(TodoistAuthorizationError.failed), attempt: attempt) }
                    }
                }
                let session: ASWebAuthenticationSession
                if #available(iOS 17.4, macOS 14.4, *) {
                    session = ASWebAuthenticationSession(
                        url: url, callback: .https(host: "thruflow.shigorefu.com", path: "/oauth/todoist/callback/"),
                        completionHandler: completion
                    )
                } else {
                    // Older system versions receive the website's PKCE-protected custom-scheme redirect.
                    session = ASWebAuthenticationSession(url: url, callbackURLScheme: "thruflow", completionHandler: completion)
                }
                session.presentationContextProvider = self
                self.session = session
                if !session.start() { finish(.failure(TodoistAuthorizationError.failed), attempt: attempt) }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                guard self?.activeAttempt == attempt else { return }
                self?.session?.cancel()
                self?.finish(.failure(CancellationError()), attempt: attempt)
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor { anchor() }

    private func finish(_ result: Result<URL, any Error>, attempt: UUID) {
        guard activeAttempt == attempt else { return }
        activeAttempt = nil
        let pending = continuation
        continuation = nil
        session = nil
        pending?.resume(with: result)
    }
}
#endif
