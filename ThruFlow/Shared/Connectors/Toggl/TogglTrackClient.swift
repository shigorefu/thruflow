#if os(macOS) || os(iOS)
import Foundation

@MainActor protocol TogglTrackClientProtocol {
    func account() async throws -> ConnectorAccount
    func workspaces() async throws -> [TogglWorkspace]
    func projects() async throws -> [TogglProject]
    func create(_ payload: TogglTimePayload) async throws -> Int64
    func find(_ payload: TogglTimePayload) async throws -> Int64?
}

private nonisolated struct TogglURLTransport: ConnectorHTTPTransport {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await URLSession.shared.data(for: request)
    }
}

/// Toggl Track API v9, distinct from the Toggl Focus API.
@MainActor final class TogglTrackClient: TogglTrackClientProtocol {
    private let token: String
    private let transport: any ConnectorHTTPTransport
    private let requestSpacing: TimeInterval
    private var lastRequest: Date = .distantPast

    init(token: String, transport: (any ConnectorHTTPTransport)? = nil, requestSpacing: TimeInterval = 1.1) {
        self.token = token
        self.transport = transport ?? TogglURLTransport()
        self.requestSpacing = requestSpacing
    }

    func account() async throws -> ConnectorAccount {
        struct User: Decodable { let id: Int64; let fullname: String?; let email: String? }
        let user: User = try await request("me")
        guard user.id > 0 else { throw ConnectorProviderError.invalidResponse }
        return ConnectorAccount(id: String(user.id), name: user.fullname ?? user.email ?? "Toggl Track")
    }

    func workspaces() async throws -> [TogglWorkspace] { try await request("me/workspaces") }

    func projects() async throws -> [TogglProject] {
        let values: [TogglProject] = try await request("me/projects")
        // Track can return can_track_time=false for active projects visible to this account.
        // Do not treat that undocumented flag as an authorization gate; the write API
        // remains authoritative and its errors are surfaced without acknowledging export.
        return values.filter { $0.active }
    }

    func create(_ payload: TogglTimePayload) async throws -> Int64 {
        let entry: TogglRemoteEntry = try await request(
            "workspaces/\(payload.workspace_id)/time_entries", body: JSONEncoder().encode(payload)
        )
        guard entry.id > 0, entry.matches(payload) else { throw ConnectorProviderError.invalidResponse }
        return entry.id
    }

    func find(_ payload: TogglTimePayload) async throws -> Int64? {
        guard let start = ISO8601DateFormatter().date(from: payload.start) else { throw TogglError.storage }
        let formatter = ISO8601DateFormatter()
        let entries: [TogglRemoteEntry] = try await request("me/time_entries", query: [
            URLQueryItem(name: "start_date", value: formatter.string(from: start.addingTimeInterval(-1))),
            URLQueryItem(name: "end_date", value: formatter.string(from: start.addingTimeInterval(1)))
        ])
        let matches = entries.filter { $0.matches(payload) }
        guard matches.count <= 1 else { throw TogglError.ambiguous }
        return matches.first?.id
    }

    private func request<Response: Decodable>(_ path: String, query: [URLQueryItem] = [], body: Data? = nil) async throws -> Response {
        guard !token.isEmpty, !token.hasPrefix("toggl_sk_") else { throw TogglError.credentials }
        let delay = requestSpacing - Date.now.timeIntervalSince(lastRequest)
        if delay > 0 { try await Task.sleep(for: .seconds(delay)) }
        try Task.checkCancellation()
        var components = URLComponents(string: "https://api.track.toggl.com/api/v9/\(path)")!
        components.queryItems = query.isEmpty ? nil : query
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 30
        request.httpMethod = body == nil ? "GET" : "POST"
        request.httpBody = body
        request.setValue("Basic " + Data("\(token):api_token".utf8).base64EncodedString(), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        lastRequest = .now
        let (data, response) = try await transport.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ConnectorProviderError.invalidResponse }
        if http.statusCode == 429 {
            throw TogglError.rateLimited(max(60, Double(http.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 3600))
        }
        if http.statusCode == 401 || http.statusCode == 403 { throw TogglError.credentials }
        guard (200..<300).contains(http.statusCode) else {
            if (400..<500).contains(http.statusCode) { throw TogglError.rejected(http.statusCode) }
            throw ConnectorProviderError.serviceUnavailable
        }
        do { return try JSONDecoder().decode(Response.self, from: data) }
        catch { throw ConnectorProviderError.invalidResponse }
    }
}
#endif
