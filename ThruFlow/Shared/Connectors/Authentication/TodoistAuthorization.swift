import CryptoKit
import Foundation
import Security

nonisolated struct TodoistAuthorizationRequest: Sendable {
    static let clientID = "https://thruflow.shigorefu.com/oauth/todoist/client.json"
    static let redirectURI = "https://thruflow.shigorefu.com/oauth/todoist/callback/"
    let state: String
    let verifier: String

    init(state: String, verifier: String) {
        self.state = state
        self.verifier = verifier
    }

    init() throws {
        self.init(state: try Self.randomString(), verifier: try Self.randomString())
    }

    var authorizationURL: URL {
        var url = URLComponents(string: "https://app.todoist.com/oauth/authorize")!
        url.queryItems = [
            URLQueryItem(name: "client_id", value: Self.clientID),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "data:read_write"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: Self.challenge(for: verifier)),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        return url.url!
    }

    func code(from callback: URL) throws -> String {
        guard let components = URLComponents(url: callback, resolvingAgainstBaseURL: false),
              components.user == nil, components.password == nil, components.port == nil,
              components.fragment == nil else { throw TodoistAuthorizationError.invalidCallback }
        let isHTTPS = callback.scheme == "https" && callback.host == "thruflow.shigorefu.com" &&
            components.percentEncodedPath == "/oauth/todoist/callback/"
        let isLegacy = callback.scheme == "thruflow" && callback.host == "oauth" && components.percentEncodedPath == "/todoist"
        guard isHTTPS || isLegacy,
              let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems,
              items.filter({ $0.name == "state" }).count == 1,
              items.first(where: { $0.name == "state" })?.value == state else {
            throw TodoistAuthorizationError.invalidCallback
        }
        if items.contains(where: { $0.name == "error" }) { throw TodoistAuthorizationError.denied }
        guard items.filter({ $0.name == "code" }).count == 1,
              let code = items.first(where: { $0.name == "code" })?.value,
              !code.isEmpty else { throw TodoistAuthorizationError.invalidCallback }
        return code
    }

    static func challenge(for verifier: String) -> String {
        base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    private static func randomString() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw TodoistAuthorizationError.failed
        }
        return base64URL(Data(bytes))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}

nonisolated enum TodoistAuthorizationError: LocalizedError {
    case invalidCallback, denied, failed, reconnect, websiteUnavailable
    var errorDescription: String? {
        switch self {
        case .invalidCallback: String(localized: "認証を確認できませんでした。もう一度接続してください。")
        case .denied: String(localized: "Todoistへの接続がキャンセルされました。")
        case .failed: String(localized: "Todoistに接続できませんでした。時間をおいて再試行してください。")
        case .reconnect: String(localized: "Todoistに再接続してください。")
        case .websiteUnavailable: String(localized: "接続用ページを読み込めませんでした。通信状態を確認して再試行してください。")
        }
    }
}

@MainActor
protocol ConnectorWebAuthenticating {
    func authenticate(url: URL) async throws -> URL
}

@MainActor
final class TodoistAuthorization {
    private let session: URLSession
    init(session: URLSession = .shared) { self.session = session }

    func authorize(using browser: any ConnectorWebAuthenticating) async throws -> ConnectorCredentials {
        let request = try TodoistAuthorizationRequest()
        let callback = try await browser.authenticate(url: request.authorizationURL)
        let code = try request.code(from: callback)
        return try await exchange([
            "grant_type": "authorization_code", "client_id": TodoistAuthorizationRequest.clientID,
            "redirect_uri": TodoistAuthorizationRequest.redirectURI, "code": code,
            "code_verifier": request.verifier,
        ])
    }

    func refresh(_ credentials: ConnectorCredentials) async throws -> ConnectorCredentials {
        guard let refreshToken = credentials.refreshToken else { throw TodoistAuthorizationError.reconnect }
        return try await exchange([
            "grant_type": "refresh_token", "client_id": TodoistAuthorizationRequest.clientID,
            "refresh_token": refreshToken,
        ])
    }

    private func exchange(_ fields: [String: String]) async throws -> ConnectorCredentials {
        var request = URLRequest(url: URL(string: "https://api.todoist.com/oauth/access_token")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        request.httpBody = fields.sorted(by: { $0.key < $1.key }).map {
            "\($0.key.addingPercentEncoding(withAllowedCharacters: allowed)!)=\($0.value.addingPercentEncoding(withAllowedCharacters: allowed)!)"
        }.joined(separator: "&").data(using: .utf8)
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw TodoistAuthorizationError.failed }
        if response.statusCode == 400 || response.statusCode == 401 { throw TodoistAuthorizationError.reconnect }
        guard (200..<300).contains(response.statusCode) else { throw TodoistAuthorizationError.failed }
        let token: TokenResponse
        do { token = try JSONDecoder().decode(TokenResponse.self, from: data) }
        catch { throw TodoistAuthorizationError.failed }
        guard !token.access_token.isEmpty, token.token_type.lowercased() == "bearer",
              token.expires_in.map({ $0.isFinite && $0 > 0 }) ?? true,
              token.refresh_token.map({ !$0.isEmpty }) ?? true else {
            throw TodoistAuthorizationError.failed
        }
        return ConnectorCredentials(
            accessToken: token.access_token, refreshToken: token.refresh_token,
            expiresAt: token.expires_in.map { Date.now.addingTimeInterval($0) },
            completionWriteAccess: token.scope.map { $0.contains("data:read_write") }
                ?? (fields["grant_type"] == "authorization_code")
        )
    }

    private struct TokenResponse: Decodable {
        let access_token: String
        let refresh_token: String?
        let expires_in: TimeInterval?
        let token_type: String
        let scope: String?
    }
}
