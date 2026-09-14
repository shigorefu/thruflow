#if os(macOS) || os(iOS)
import Foundation

@MainActor protocol TogglExportStorage {
    func load() throws -> TogglExportState
    func save(_ state: TogglExportState) throws
}

@MainActor final class TogglFileStorage: TogglExportStorage {
    private let url: URL
    init(url: URL? = nil) {
        self.url = url ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ThruFlow/Toggl/export-v1.json")
    }
    func load() throws -> TogglExportState {
        guard FileManager.default.fileExists(atPath: url.path) else { return TogglExportState() }
        let state = try JSONDecoder().decode(TogglExportState.self, from: Data(contentsOf: url))
        guard state.version == 1, Set(state.jobs.map(\.id)).count == state.jobs.count else { throw TogglError.storage }
        return state
    }
    func save(_ state: TogglExportState) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(state).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}

@MainActor final class TogglMemoryStorage: TogglExportStorage {
    var state = TogglExportState()
    func load() throws -> TogglExportState { state }
    func save(_ state: TogglExportState) throws { self.state = state }
}
#endif
