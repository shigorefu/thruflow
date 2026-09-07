#if os(macOS) || os(iOS)
import Foundation

nonisolated protocol ConnectorHTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

private nonisolated struct URLSessionConnectorTransport: ConnectorHTTPTransport {
    let session: URLSession

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}

/// Todoist API v1, read-only. Credentials are supplied by the application Keychain boundary.
/// https://developer.todoist.com/api/v1/
@MainActor
final class TodoistConnectorClient: ConnectorClient {
    private let accessToken: String
    private let transport: any ConnectorHTTPTransport
    private let calendar: Calendar

    init(accessToken: String, session: URLSession = .shared) {
        self.accessToken = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        self.transport = URLSessionConnectorTransport(session: session)
        self.calendar = .current
    }

    init(accessToken: String, transport: any ConnectorHTTPTransport, calendar: Calendar = .current) {
        self.accessToken = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        self.transport = transport
        self.calendar = calendar
    }

    func account() async throws -> ConnectorAccount {
        var request = try makeRequest(path: "sync")
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        // No commands: this POST only reads the user's account identity.
        request.httpBody = Data("sync_token=*&resource_types=%5B%22user%22%5D".utf8)
        let response: TodoistUserResponse = try await decode(request)
        guard !response.user.id.isEmpty else { throw ConnectorProviderError.invalidResponse }
        let name = response.user.fullName?.trimmingCharacters(in: .whitespacesAndNewlines)
        return ConnectorAccount(id: response.user.id, name: name?.isEmpty == false ? name! : "Todoist")
    }

    func sources() async throws -> [ConnectorSource] {
        let projects: [TodoistProject] = try await pages(path: "projects", query: [])
        var seen = Set<String>()
        return try projects.filter { $0.isDeleted != true && $0.isArchived != true }.map { project in
            guard !project.id.isEmpty, seen.insert(project.id).inserted else {
                throw ConnectorProviderError.invalidResponse
            }
            return ConnectorSource(id: project.id, name: project.name)
        }
    }

    func tasks(sourceIDs: Set<String>) async throws -> [ConnectorTask] {
        guard !sourceIDs.isEmpty else { return [] }
        var results: [ConnectorTask] = []
        var seen = Set<String>()
        for sourceID in sourceIDs.sorted() {
            let items: [TodoistTask] = try await pages(
                path: "tasks",
                query: [URLQueryItem(name: "project_id", value: sourceID)]
            )
            for item in items where item.isDeleted != true {
                guard !item.id.isEmpty, item.projectID == sourceID else {
                    throw ConnectorProviderError.invalidResponse
                }
                guard seen.insert(item.id).inserted else {
                    throw ConnectorProviderError.ambiguousTaskIdentity
                }
                results.append(ConnectorTask(
                    id: item.id,
                    sourceID: item.projectID,
                    title: item.content,
                    notes: item.description?.isEmpty == false ? item.description : nil,
                    dueDate: try TodoistDateParser.parse(item.due?.date ?? item.deadline?.date, calendar: calendar),
                    isCompleted: item.checked ?? false,
                    completedAt: try TodoistDateParser.parse(item.completedAt, calendar: calendar),
                    url: URL(string: "https://app.todoist.com/app/task/")?.appendingPathComponent(item.id)
                ))
            }
        }
        return results
    }

    private func pages<Item: Decodable>(path: String, query: [URLQueryItem]) async throws -> [Item] {
        var result: [Item] = []
        var cursor: String?
        var seenCursors = Set<String>()
        repeat {
            try Task.checkCancellation()
            var pageQuery = query + [URLQueryItem(name: "limit", value: "200")]
            if let cursor {
                pageQuery.append(URLQueryItem(name: "cursor", value: cursor))
            }
            let request = try makeRequest(path: path, query: pageQuery)
            let page: TodoistPage<Item> = try await decode(request)
            result.append(contentsOf: page.results)
            cursor = page.nextCursor
            if let cursor {
                guard !cursor.isEmpty, seenCursors.insert(cursor).inserted else {
                    throw ConnectorProviderError.invalidResponse
                }
            }
        } while cursor != nil
        return result
    }

    private func makeRequest(path: String, query: [URLQueryItem] = []) throws -> URLRequest {
        guard !accessToken.isEmpty,
              !accessToken.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.contains($0) || CharacterSet.controlCharacters.contains($0) })
        else { throw ConnectorProviderError.invalidCredential }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.todoist.com"
        components.path = "/api/v1/\(path)"
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url else { throw ConnectorProviderError.invalidResponse }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func decode<Value: Decodable>(_ request: URLRequest) async throws -> Value {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await transport.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw ConnectorProviderError.networkUnavailable
        }
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else { throw ConnectorProviderError.invalidResponse }
        switch http.statusCode {
        case 200..<300:
            break
        case 401, 403:
            throw ConnectorProviderError.invalidCredential
        case 404:
            throw ConnectorProviderError.sourceUnavailable
        case 429:
            throw ConnectorProviderError.rateLimited
        case 500...599:
            throw ConnectorProviderError.serviceUnavailable
        default:
            throw ConnectorProviderError.invalidResponse
        }
        do {
            return try JSONDecoder().decode(Value.self, from: data)
        } catch {
            // Do not expose response bodies or credentials in user-facing errors.
            throw ConnectorProviderError.invalidResponse
        }
    }
}

private nonisolated struct TodoistUserResponse: Decodable {
    let user: TodoistUser
}

private nonisolated struct TodoistUser: Decodable {
    let id: String
    let fullName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
    }
}

private nonisolated struct TodoistPage<Item: Decodable>: Decodable {
    let results: [Item]
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case results
        case nextCursor = "next_cursor"
    }
}

private nonisolated struct TodoistProject: Decodable {
    let id: String
    let name: String
    let isDeleted: Bool?
    let isArchived: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name
        case isDeleted = "is_deleted"
        case isArchived = "is_archived"
    }
}

private nonisolated struct TodoistTask: Decodable {
    let id: String
    let projectID: String
    let content: String
    let description: String?
    let due: TodoistDue?
    let deadline: TodoistDue?
    let checked: Bool?
    let isDeleted: Bool?
    let completedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, content, description, due, deadline, checked
        case projectID = "project_id"
        case isDeleted = "is_deleted"
        case completedAt = "completed_at"
    }
}

private nonisolated struct TodoistDue: Decodable {
    let date: String
}

/// Todoist distinguishes date-only, floating local time, and absolute timestamps.
nonisolated enum TodoistDateParser {
    static func parse(_ value: String?, calendar: Calendar) throws -> Date? {
        guard let value else { return nil }
        let absolute = ISO8601DateFormatter()
        absolute.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = absolute.date(from: value) { return date }
        absolute.formatOptions = [.withInternetDateTime]
        if let date = absolute.date(from: value) { return date }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = calendar.timeZone
        formatter.isLenient = false
        for format in ["yyyy-MM-dd", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) { return date }
        }
        throw ConnectorProviderError.invalidResponse
    }
}
#endif
