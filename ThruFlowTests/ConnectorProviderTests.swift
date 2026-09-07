import Foundation
import Testing
@testable import ThruFlow

@Suite(.serialized)
@MainActor
struct ConnectorProviderTests {
    @Test func todoistAccountUsesAuthenticatedReadOnlySyncRequest() async throws {
        let transport = ConnectorStubTransport([
            .init(json: #"{"user":{"id":"account-1","full_name":"Test User","token":"ignored-server-token"}}"#)
        ])
        let client = TodoistConnectorClient(accessToken: " test-token ", transport: transport)
        let account = try await client.account()
        #expect(account == ConnectorAccount(id: "account-1", name: "Test User"))
        let requests = await transport.recordedRequests()
        let request = try #require(requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://api.todoist.com/api/v1/sync")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
        let body = String(data: try #require(request.httpBody), encoding: .utf8)
        #expect(body == "sync_token=*&resource_types=%5B%22user%22%5D")
        #expect(body?.contains("commands") == false)
    }

    @Test func todoistProjectsLoadEveryPageAndExcludeArchivedSources() async throws {
        let transport = ConnectorStubTransport([
            .init(json: #"{"results":[{"id":"project-a","name":"Work"}],"next_cursor":"next+page/="}"#),
            .init(json: #"{"results":[{"id":"old","name":"Old","is_archived":true},{"id":"project-b","name":"Home"}],"next_cursor":null}"#)
        ])
        let client = TodoistConnectorClient(accessToken: "test-token", transport: transport)
        let sources = try await client.sources()
        #expect(sources.map(\.id) == ["project-a", "project-b"])
        let requests = await transport.recordedRequests()
        #expect(requests.count == 2)
        let query = URLComponents(url: try #require(requests.last?.url), resolvingAgainstBaseURL: false)?.queryItems
        #expect(query?.first(where: { $0.name == "cursor" })?.value == "next+page/=")
        #expect(requests.allSatisfy { $0.httpMethod == "GET" })
    }

    @Test func todoistTasksRespectSelectedProjectAndPreserveFloatingDates() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        let transport = ConnectorStubTransport([
            .init(json: #"{"results":[{"id":"task-a","project_id":"project-a","content":"Plan","description":"Notes","due":{"date":"2026-09-07"},"checked":false},{"id":"task-b","project_id":"project-a","content":"Call","due":{"date":"2026-09-07T18:30:00"}},{"id":"deleted","project_id":"project-a","content":"Deleted","is_deleted":true}],"next_cursor":null}"#)
        ])
        let client = TodoistConnectorClient(accessToken: "test-token", transport: transport, calendar: calendar)
        let tasks = try await client.tasks(sourceIDs: ["project-a"])
        #expect(tasks.map(\.id) == ["task-a", "task-b"])
        #expect(tasks[0].notes == "Notes")
        #expect(tasks[0].url?.absoluteString == "https://app.todoist.com/app/task/task-a")
        let firstDate = try #require(tasks[0].dueDate)
        let secondDate = try #require(tasks[1].dueDate)
        #expect(calendar.component(.day, from: firstDate) == 7)
        #expect(calendar.component(.hour, from: firstDate) == 0)
        #expect(calendar.component(.hour, from: secondDate) == 18)
        #expect(calendar.component(.minute, from: secondDate) == 30)
        let requests = await transport.recordedRequests()
        let query = URLComponents(url: try #require(requests.first?.url), resolvingAgainstBaseURL: false)?.queryItems
        #expect(query?.first(where: { $0.name == "project_id" })?.value == "project-a")
    }

    @Test func emptySourceSelectionDoesNotFetchAllTasks() async throws {
        let transport = ConnectorStubTransport([])
        let client = TodoistConnectorClient(accessToken: "test-token", transport: transport)
        #expect(try await client.tasks(sourceIDs: []).isEmpty)
        #expect(await transport.recordedRequests().isEmpty)
    }

    @Test func repeatedPaginationCursorFailsInsteadOfLooping() async {
        let response = #"{"results":[],"next_cursor":"loop"}"#
        let transport = ConnectorStubTransport([.init(json: response), .init(json: response)])
        let client = TodoistConnectorClient(accessToken: "test-token", transport: transport)
        await #expect(throws: ConnectorProviderError.invalidResponse) {
            try await client.sources()
        }
        #expect(await transport.recordedRequests().count == 2)
    }

    @Test func authenticationAndRateLimitErrorsDoNotExposeResponseBodies() async {
        for (status, expected) in [(401, ConnectorProviderError.invalidCredential), (429, .rateLimited)] {
            let transport = ConnectorStubTransport([.init(json: "sensitive response body", statusCode: status)])
            let client = TodoistConnectorClient(accessToken: "test-token", transport: transport)
            await #expect(throws: expected) {
                try await client.sources()
            }
            #expect(expected.localizedDescription.contains("sensitive") == false)
        }
    }

    @Test func invalidDatesFailInsteadOfSilentlyRemovingStoredDueDates() async {
        let transport = ConnectorStubTransport([
            .init(json: #"{"results":[{"id":"task-a","project_id":"project-a","content":"Plan","due":{"date":"invalid-date"}}],"next_cursor":null}"#)
        ])
        let client = TodoistConnectorClient(accessToken: "test-token", transport: transport)
        await #expect(throws: ConnectorProviderError.invalidResponse) {
            try await client.tasks(sourceIDs: ["project-a"])
        }
    }

    @Test func absoluteDatesKeepTheirInstantAcrossTimeZones() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        let timestamp = try #require(try TodoistDateParser.parse("2026-09-07T09:30:00.123456Z", calendar: calendar))
        #expect(calendar.component(.hour, from: timestamp) == 18)
        #expect(calendar.component(.minute, from: timestamp) == 30)
        #expect(try TodoistDateParser.parse(nil, calendar: calendar) == nil)
    }

    @Test func reminderExternalIdentityIsSharedWhileFallbackIsInstallationScoped() {
        let first = RemindersTaskIdentity.make(externalID: "server-id", localID: "local-a", installationID: "mac", isExchange: false)
        let second = RemindersTaskIdentity.make(externalID: "server-id", localID: "local-b", installationID: "phone", isExchange: false)
        #expect(first == second)
        #expect(first == "external:server-id")
        let localMac = RemindersTaskIdentity.make(externalID: nil, localID: "local", installationID: "mac", isExchange: false)
        let localPhone = RemindersTaskIdentity.make(externalID: nil, localID: "local", installationID: "phone", isExchange: false)
        #expect(localMac != localPhone)
        let exchange = RemindersTaskIdentity.make(externalID: "server-id", localID: "exchange-local", installationID: "mac", isExchange: true)
        #expect(exchange == "local:mac:exchange-local")
        let localWithExternalID = RemindersTaskIdentity.make(externalID: "local-id", localID: "local-id", installationID: "mac", isExchange: false, isLocal: true)
        #expect(localWithExternalID == "local:mac:local-id")
    }

    @Test func credentialsWithHeaderControlCharactersNeverReachTransport() async {
        let transport = ConnectorStubTransport([])
        let client = TodoistConnectorClient(accessToken: "token\r\nInjected: value", transport: transport)
        await #expect(throws: ConnectorProviderError.invalidCredential) {
            try await client.account()
        }
        #expect(await transport.recordedRequests().isEmpty)
    }
}

private nonisolated struct ConnectorStubReply: Sendable {
    let json: String
    var statusCode: Int = 200
}

private actor ConnectorStubTransport: ConnectorHTTPTransport {
    private var replies: [ConnectorStubReply]
    private var requests: [URLRequest] = []

    init(_ replies: [ConnectorStubReply]) {
        self.replies = replies
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        guard !replies.isEmpty, let url = request.url else { throw URLError(.badServerResponse) }
        let reply = replies.removeFirst()
        let response = HTTPURLResponse(url: url, statusCode: reply.statusCode, httpVersion: nil, headerFields: nil)!
        return (Data(reply.json.utf8), response)
    }

    func recordedRequests() -> [URLRequest] {
        requests
    }
}
