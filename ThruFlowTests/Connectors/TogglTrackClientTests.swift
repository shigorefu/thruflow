import Foundation
import Testing
@testable import ThruFlow

@MainActor struct TogglTrackClientTests {
    private var payload: TogglTimePayload {
        TogglTimePayload(workspace_id: 10, project_id: 20, description: "Study", start: "2026-09-14T01:00:00Z", duration: 1500)
    }
    private let entry = #"{"id":42,"workspace_id":10,"project_id":20,"description":"Study","start":"2026-09-14T01:00:00.000Z","duration":1500,"tags":["ThruFlow"]}"#

    @Test func authenticationAndCompletedTimePayloadUseTrackV9() async throws {
        let transport = TogglHTTPStub(responses: [(200, #"{"id":1,"fullname":"Tester"}"#, [:]), (200, entry, [:])])
        let client = TogglTrackClient(token: "test-token", transport: transport, requestSpacing: 0)
        #expect(try await client.account().id == "1")
        #expect(try await client.create(payload) == 42)
        let requests = await transport.requests
        #expect(requests[0].url?.absoluteString == "https://api.track.toggl.com/api/v9/me")
        #expect(requests[0].value(forHTTPHeaderField: "Authorization") == "Basic " + Data("test-token:api_token".utf8).base64EncodedString())
        #expect(requests[1].httpMethod == "POST")
        #expect(requests[1].url?.path == "/api/v9/workspaces/10/time_entries")
        let bodyData = try #require(requests[1].httpBody)
        let body = try #require(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        #expect(body["duration"] as? Int == 1500)
        #expect(body["created_with"] as? String == "ThruFlow")
        #expect(body["stop"] == nil) // Duration excludes pauses, independently of the wall-clock end.
        #expect(body["api_token"] == nil)
    }

    @Test func activeProjectsRemainSelectableRegardlessOfTrackTimeHint() async throws {
        let response = #"[{"id":20,"workspace_id":10,"name":"Study","active":true,"can_track_time":false},{"id":21,"workspace_id":10,"name":"Work","active":true,"can_track_time":true},{"id":22,"workspace_id":11,"name":"Other workspace","active":true},{"id":23,"workspace_id":10,"name":"Archived","active":false,"can_track_time":true}]"#
        let transport = TogglHTTPStub(responses: [(200, response, [:])])
        let client = TogglTrackClient(token: "test", transport: transport, requestSpacing: 0)
        let projects = try await client.projects()
        #expect(projects.map(\.id) == [20, 21, 22])
        #expect(projects.filter { $0.workspace_id == 10 }.map(\.id) == [20, 21])
        #expect(await transport.requests.first?.url?.path == "/api/v9/me/projects")
    }

    @Test func lookupChecksIdentityAndRejectsAmbiguousMatches() async throws {
        let transport = TogglHTTPStub(responses: [(200, "[\(entry)]", [:]), (200, "[\(entry),\(entry)]", [:])])
        let client = TogglTrackClient(token: "test", transport: transport, requestSpacing: 0)
        #expect(try await client.find(payload) == 42)
        do { _ = try await client.find(payload); Issue.record("Ambiguous match must fail") }
        catch TogglError.ambiguous { }
        let request = try #require(await transport.requests.first)
        let url = try #require(request.url)
        let query = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(query.map(\.name) == ["start_date", "end_date"])
        let foreign = entry.replacingOccurrences(of: "\"workspace_id\":10", with: "\"workspace_id\":11")
        let decoded = try JSONDecoder().decode(TogglRemoteEntry.self, from: Data(foreign.utf8))
        #expect(!decoded.matches(payload))
    }

    @Test func rejectsFocusTokenBeforeSendingAndPreservesQuotaDelay() async throws {
        let transport = TogglHTTPStub(responses: [(429, "{}", ["Retry-After":"120"])])
        let focus = TogglTrackClient(token: "toggl_sk_wrong-product", transport: transport, requestSpacing: 0)
        do { _ = try await focus.account(); Issue.record("Focus token must be rejected") }
        catch TogglError.credentials { }
        #expect(await transport.requests.isEmpty)
        let client = TogglTrackClient(token: "test", transport: transport, requestSpacing: 0)
        do { _ = try await client.account(); Issue.record("Expected rate limit") }
        catch TogglError.rateLimited(let seconds) { #expect(seconds == 120) }
    }

    @Test func malformedSuccessIsNotTreatedAsAcknowledged() async throws {
        let transport = TogglHTTPStub(responses: [(200, "{}", [:])])
        let client = TogglTrackClient(token: "test", transport: transport, requestSpacing: 0)
        do { _ = try await client.create(payload); Issue.record("Malformed receipt must fail") }
        catch ConnectorProviderError.invalidResponse { }
    }
}

private actor TogglHTTPStub: ConnectorHTTPTransport {
    var responses: [(Int, String, [String: String])]
    var requests: [URLRequest] = []
    init(responses: [(Int, String, [String: String])]) { self.responses = responses }
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        guard !responses.isEmpty else { throw URLError(.badServerResponse) }
        let (status, body, headers) = responses.removeFirst()
        return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!)
    }
}
