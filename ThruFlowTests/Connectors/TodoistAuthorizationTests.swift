import AuthenticationServices
import Foundation
import Testing
@testable import ThruFlow

@Suite(.serialized)
@MainActor
struct TodoistAuthorizationTests {
    @Test func pkceMatchesRFC7636AppendixB() {
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        #expect(TodoistAuthorizationRequest.challenge(for: verifier) == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    @Test func authorizationUsesFreshUnpaddedPKCEAndReadOnlyScope() throws {
        let first = try TodoistAuthorizationRequest()
        let second = try TodoistAuthorizationRequest()
        #expect(first.state != second.state)
        #expect(first.verifier != second.verifier)
        #expect(first.state.count == 43)
        #expect(first.verifier.count == 43)
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        #expect(first.verifier.unicodeScalars.allSatisfy { allowed.contains($0) })
        let query = try #require(URLComponents(url: first.authorizationURL, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(first.authorizationURL.host == "app.todoist.com")
        #expect(query.first { $0.name == "client_id" }?.value == TodoistAuthorizationRequest.clientID)
        #expect(query.first { $0.name == "redirect_uri" }?.value == TodoistAuthorizationRequest.redirectURI)
        #expect(query.first { $0.name == "scope" }?.value == "data:read_write")
        #expect(query.first { $0.name == "code_challenge_method" }?.value == "S256")
        #expect(query.first { $0.name == "code_challenge" }?.value == TodoistAuthorizationRequest.challenge(for: first.verifier))
        #expect(!query.contains { $0.name == "client_secret" || $0.name == "code_verifier" })
    }

    @Test func canonicalHTTPSAndLegacyCallbacksPreserveCode() throws {
        let request = TodoistAuthorizationRequest(state: "expected-state", verifier: "test-verifier")
        let urls = [
            "https://thruflow.shigorefu.com/oauth/todoist/callback/?state=expected-state&code=code%2Bvalue%2F",
            "thruflow://oauth/todoist?state=expected-state&code=code%2Bvalue%2F",
        ]
        for value in urls {
            let callback = try #require(URL(string: value))
            #expect(try request.code(from: callback) == "code+value/")
        }
    }

    @Test func callbackRejectsForeignOriginsAmbiguousQueriesAndStateInFragment() throws {
        let request = TodoistAuthorizationRequest(state: "expected-state", verifier: "test-verifier")
        let base = "https://thruflow.shigorefu.com/oauth/todoist/callback/"
        let invalid = [
            "\(base)?state=wrong&code=c",
            "\(base)?code=c",
            "\(base)?state=expected-state&state=expected-state&code=c",
            "\(base)?state=expected-state&code=c&code=c",
            "\(base)?state=expected-state",
            "\(base)?state=expected-state&code=",
            "\(base)#state=expected-state&code=c",
            "\(base)?state=expected-state&code=c#foreign-fragment",
            "https://foreign.example/oauth/todoist/callback/?state=expected-state&code=c",
            "https://thruflow.shigorefu.com.foreign.example/oauth/todoist/callback/?state=expected-state&code=c",
            "https://thruflow.shigorefu.com/oauth/not-todoist/callback/?state=expected-state&code=c",
            "http://thruflow.shigorefu.com/oauth/todoist/callback/?state=expected-state&code=c",
            "https://thruflow.shigorefu.com:444/oauth/todoist/callback/?state=expected-state&code=c",
            "https://user@thruflow.shigorefu.com/oauth/todoist/callback/?state=expected-state&code=c",
            "https://user:password@thruflow.shigorefu.com/oauth/todoist/callback/?state=expected-state&code=c",
            "thruflow://foreign/todoist?state=expected-state&code=c",
            "thruflow://oauth/other?state=expected-state&code=c",
        ]
        for value in invalid {
            let callback = try #require(URL(string: value))
            #expect(throws: TodoistAuthorizationError.self) {
                try request.code(from: callback)
            }
        }
    }

    @Test func deniedCallbackRequiresMatchingState() throws {
        let request = TodoistAuthorizationRequest(state: "expected-state", verifier: "test-verifier")
        let denied = try #require(URL(string: "\(TodoistAuthorizationRequest.redirectURI)?state=expected-state&error=access_denied"))
        do {
            _ = try request.code(from: denied)
            Issue.record("A denied callback must not yield an authorization code.")
        } catch TodoistAuthorizationError.denied { }
        let wrongState = try #require(URL(string: "\(TodoistAuthorizationRequest.redirectURI)?state=wrong&error=access_denied"))
        do {
            _ = try request.code(from: wrongState)
            Issue.record("A callback with wrong state must be rejected before handling denial.")
        } catch TodoistAuthorizationError.invalidCallback { }
    }

    @Test func modernSystemMatcherRecognizesCanonicalHTTPSRedirect() throws {
        if #available(macOS 14.4, iOS 17.4, *) {
            let callback = ASWebAuthenticationSession.Callback.https(
                host: "thruflow.shigorefu.com",
                path: "/oauth/todoist/callback/"
            )
            let url = try #require(URL(string: "\(TodoistAuthorizationRequest.redirectURI)?state=s&code=c"))
            #expect(callback.matchesURL(url))
            #expect(!callback.matchesURL(URL(string: "https://foreign.example/oauth/todoist/callback/?state=s&code=c")!))
        }
    }

    @Test func codeExchangeIncludesMatchingVerifierAndNeverAClientSecret() async throws {
        let fixture = AuthHTTPFixture(replies: [
            .init(json: #"{"access_token":"new-access","refresh_token":"new-refresh","expires_in":3600,"token_type":"Bearer"}"#)
        ])
        defer { fixture.close() }
        let browser = AuthBrowserStub()
        let authorization = TodoistAuthorization(session: fixture.session)
        let credentials = try await authorization.authorize(using: browser)
        #expect(credentials.accessToken == "new-access")
        #expect(credentials.refreshToken == "new-refresh")
        let request = try #require(fixture.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://api.todoist.com/oauth/access_token")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
        let body = try formFields(request)
        #expect(body["grant_type"] == "authorization_code")
        #expect(body["client_id"] == TodoistAuthorizationRequest.clientID)
        #expect(body["redirect_uri"] == TodoistAuthorizationRequest.redirectURI)
        #expect(body["code"] == "code+value/")
        #expect(body["client_secret"] == nil)
        let verifier = try #require(body["code_verifier"])
        let browserURL = try #require(browser.openedURL)
        let challenge = URLComponents(url: browserURL, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "code_challenge" }?.value
        #expect(challenge == TodoistAuthorizationRequest.challenge(for: verifier))
    }

    @Test func invalidBrowserStateNeverReachesTokenEndpoint() async throws {
        let fixture = AuthHTTPFixture(replies: [])
        defer { fixture.close() }
        let browser = AuthBrowserStub(replacesState: true)
        let authorization = TodoistAuthorization(session: fixture.session)
        await #expect(throws: TodoistAuthorizationError.self) {
            try await authorization.authorize(using: browser)
        }
        #expect(fixture.requests.isEmpty)
    }

    @Test func refreshReturnsRotatedCredentialAndExpiry() async throws {
        let fixture = AuthHTTPFixture(replies: [
            .init(json: #"{"access_token":"next-access","refresh_token":"rotated-refresh","expires_in":3600,"token_type":"bearer"}"#)
        ])
        defer { fixture.close() }
        let authorization = TodoistAuthorization(session: fixture.session)
        let before = Date.now
        let credentials = try await authorization.refresh(ConnectorCredentials(
            accessToken: "old-access", refreshToken: "old-refresh", expiresAt: .distantPast
        ))
        #expect(credentials.accessToken == "next-access")
        #expect(credentials.refreshToken == "rotated-refresh")
        let expiry = try #require(credentials.expiresAt)
        #expect(expiry >= before.addingTimeInterval(3600))
        #expect(expiry <= Date.now.addingTimeInterval(3600))
        let body = try formFields(try #require(fixture.requests.first))
        #expect(body["grant_type"] == "refresh_token")
        #expect(body["refresh_token"] == "old-refresh")
        #expect(body["client_id"] == TodoistAuthorizationRequest.clientID)
        #expect(body["client_secret"] == nil)
        #expect(body["code_verifier"] == nil)
    }

    @Test func missingRotationNeverRestoresConsumedRefreshToken() async throws {
        // Todoist grace-window retries may omit the new refresh token.
        // Reusing the consumed input after the grace window revokes the account's tokens.
        let fixture = AuthHTTPFixture(replies: [
            .init(json: #"{"access_token":"next-access","expires_in":3600,"token_type":"Bearer"}"#)
        ])
        defer { fixture.close() }
        let credentials = try await TodoistAuthorization(session: fixture.session).refresh(
            ConnectorCredentials(accessToken: "old-access", refreshToken: "consumed-refresh")
        )
        #expect(credentials.refreshToken == nil)
        #expect(credentials.accessToken == "next-access")
    }

    @Test func missingRefreshTokenRequiresReconnectionWithoutNetworkRequest() async throws {
        let fixture = AuthHTTPFixture(replies: [])
        defer { fixture.close() }
        do {
            _ = try await TodoistAuthorization(session: fixture.session).refresh(
                ConnectorCredentials(accessToken: "expired-access", expiresAt: .distantPast)
            )
            Issue.record("Expired credentials without a refresh token require reconnection.")
        } catch TodoistAuthorizationError.reconnect { }
        #expect(fixture.requests.isEmpty)
    }

    @Test func tokenEndpointRejectsInvalidTokenPayloads() async throws {
        for json in [
            #"{"access_token":"","token_type":"Bearer"}"#,
            #"{"access_token":"access","token_type":"mac"}"#,
            #"{"access_token":"access","token_type":"Bearer","refresh_token":"","expires_in":3600}"#,
            #"{"access_token":"access","token_type":"Bearer","expires_in":-1}"#,
        ] {
            let fixture = AuthHTTPFixture(replies: [.init(json: json)])
            defer { fixture.close() }
            let authorization = TodoistAuthorization(session: fixture.session)
            await #expect(throws: TodoistAuthorizationError.self) {
                try await authorization.refresh(ConnectorCredentials(accessToken: "expired", refreshToken: "refresh"))
            }
        }
    }

    @Test func revokedRefreshTokenRequiresReconnection() async throws {
        let fixture = AuthHTTPFixture(replies: [.init(json: #"{"error":"invalid_grant"}"#, status: 401)])
        defer { fixture.close() }
        do {
            _ = try await TodoistAuthorization(session: fixture.session).refresh(
                ConnectorCredentials(accessToken: "old-access", refreshToken: "revoked-refresh")
            )
            Issue.record("A revoked refresh token must require reconnection.")
        } catch TodoistAuthorizationError.reconnect { }
    }

    private func formFields(_ request: URLRequest) throws -> [String: String] {
        let data = try #require(request.httpBody)
        let body = try #require(String(data: data, encoding: .utf8))
        let items = try #require(URLComponents(string: "https://test.invalid/?\(body)")?.queryItems)
        return Dictionary(uniqueKeysWithValues: items.compactMap { item in item.value.map { (item.name, $0) } })
    }
}

@MainActor
private final class AuthBrowserStub: ConnectorWebAuthenticating {
    var openedURL: URL?
    private let replacesState: Bool

    init(replacesState: Bool = false) { self.replacesState = replacesState }

    func authenticate(url: URL) async throws -> URL {
        openedURL = url
        let state = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "state" }?.value
        var callback = URLComponents(string: TodoistAuthorizationRequest.redirectURI)!
        callback.queryItems = [
            URLQueryItem(name: "state", value: replacesState ? "foreign-state" : state),
            URLQueryItem(name: "code", value: "code+value/"),
        ]
        return callback.url!
    }
}

private nonisolated struct AuthHTTPReply: Sendable {
    let json: String
    var status: Int = 200
}

@MainActor
private final class AuthHTTPFixture {
    let session: URLSession
    private let id = UUID().uuidString

    init(replies: [AuthHTTPReply]) {
        AuthURLProtocol.register(id: id, replies: replies)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AuthURLProtocol.self]
        configuration.httpAdditionalHeaders = ["X-ThruFlow-Auth-Test": id]
        session = URLSession(configuration: configuration)
    }

    var requests: [URLRequest] { AuthURLProtocol.requests(for: id) }

    func close() {
        session.invalidateAndCancel()
        AuthURLProtocol.remove(id: id)
    }
}

/// All session requests are intercepted. This suite never contacts Todoist.
private nonisolated final class AuthURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var repliesByID: [String: [AuthHTTPReply]] = [:]
    private nonisolated(unsafe) static var requestsByID: [String: [URLRequest]] = [:]

    static func register(id: String, replies: [AuthHTTPReply]) {
        lock.lock()
        defer { lock.unlock() }
        repliesByID[id] = replies
        requestsByID[id] = []
    }

    static func requests(for id: String) -> [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return requestsByID[id] ?? []
    }

    static func remove(id: String) {
        lock.lock()
        defer { lock.unlock() }
        repliesByID.removeValue(forKey: id)
        requestsByID.removeValue(forKey: id)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let id = request.value(forHTTPHeaderField: "X-ThruFlow-Auth-Test"), let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        var captured = request
        if captured.httpBody == nil, let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                data.append(buffer, count: count)
            }
            captured.httpBody = data
        }
        Self.lock.lock()
        Self.requestsByID[id, default: []].append(captured)
        let reply: AuthHTTPReply?
        if Self.repliesByID[id]?.isEmpty == false {
            reply = Self.repliesByID[id]?.removeFirst()
        } else { reply = nil }
        Self.lock.unlock()
        guard let reply else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let response = HTTPURLResponse(url: url, statusCode: reply.status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(reply.json.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() { }
}
