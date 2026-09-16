import Foundation
import SwiftData

/// Non-secret identity data travels with the Todo through private CloudKit.
/// Source is metadata, not identity: moving a task between lists must not copy it.
nonisolated struct ExternalTaskLink: Codable, Equatable, Sendable {
    var provider: ConnectorProviderID
    var accountID: String
    var taskID: String
    var sourceID: String
    var originalURL: URL?
    var lastSyncedAt: Date
    /// Distinguishes reconciliation tombstones from intentional user deletion.
    var supersededByTodoID: UUID? = nil
    var remoteCompletion: Bool? = nil
    var completionChanges: [ConnectorCompletionChange]? = nil
    var acknowledgedCompletionIDs: [UUID]? = nil

    var identity: Identity {
        Identity(provider: provider, accountID: accountID, taskID: taskID)
    }

    struct Identity: Hashable {
        let provider: ConnectorProviderID
        let accountID: String
        let taskID: String
    }

    static func decode(_ value: String) throws -> Self {
        try JSONDecoder().decode(Self.self, from: Data(value.utf8))
    }

    func encoded() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return String(decoding: try encoder.encode(self), as: UTF8.self)
    }
}

/// Non-secret durable outbox, saved atomically with the local checkbox state.
nonisolated struct ConnectorCompletionChange: Codable, Equatable, Sendable, Identifiable {
    var id: UUID = UUID()
    var isCompleted: Bool
    var createdAt: Date
}

nonisolated struct ConnectorImportResult: Equatable {
    var inserted: Int = 0
    var updated: Int = 0
    var skipped: Int = 0
}

nonisolated enum ConnectorImportError: LocalizedError {
    case unavailableArea
    case invalidIdentity

    var errorDescription: String? {
        switch self {
        case .unavailableArea:
            String(localized: "接続先には通常またはナイスの活動領域を選んでください。")
        case .invalidIdentity:
            String(localized: "接続先のタスクを識別できませんでした。もう一度更新してください。")
        }
    }
}

@MainActor
struct ConnectorTaskImporter {
    private var save: (ModelContext) throws -> Void

    init(save: @escaping (ModelContext) throws -> Void = { try $0.save() }) {
        self.save = save
    }

    /// Imports tasks and adopts source completion only when no local change is pending.
    func importTasks(
        _ tasks: [ConnectorTask],
        provider: ConnectorProviderID,
        accountID: String,
        area: Area,
        modelContext: ModelContext,
        now: Date = .now
    ) throws -> ConnectorImportResult {
        guard !area.isArchived, area.type != .habit else {
            throw ConnectorImportError.unavailableArea
        }
        guard !accountID.isEmpty,
              tasks.allSatisfy({ !$0.id.isEmpty && !$0.sourceID.isEmpty }) else {
            throw ConnectorImportError.invalidIdentity
        }

        let journal = MutationJournal(modelContext: modelContext)
        do {
            let todos = try modelContext.fetch(FetchDescriptor<Todo>())
            let linked = try linkedTodos(todos)
            let repaired = try reconcile(linked, modelContext: modelContext, journal: journal, now: now)
            var existing = Dictionary(grouping: linked, by: { $0.link.identity })
            var seen = Set<String>()
            var result = ConnectorImportResult()
            var nextSortIndex = (todos.map(\.sortIndex).min() ?? 0) - 1

            for task in tasks {
                guard seen.insert(task.id).inserted else {
                    result.skipped += 1
                    continue
                }
                var link = ExternalTaskLink(
                    provider: provider,
                    accountID: accountID,
                    taskID: task.id,
                    sourceID: task.sourceID,
                    originalURL: task.url,
                    lastSyncedAt: now
                )
                if let matches = existing[link.identity] {
                    // Decode current metadata after reconciliation, since a
                    // previously active duplicate may now be a tombstone.
                    let canonical = try matches.filter {
                        try $0.todo.externalTaskLinkRawValue.map(ExternalTaskLink.decode)?
                            .supersededByTodoID == nil
                    }.sorted { canonicalOrder($0.todo, $1.todo) }.first?.todo
                    guard let canonical, !canonical.isDeleted, !canonical.isArchived else {
                        result.skipped += 1
                        continue
                    }
                    journal.capture(canonical)
                    canonical.title = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    canonical.deadline = task.dueDate
                    let previous = canonical.externalTaskLink
                    link.completionChanges = previous?.completionChanges
                    link.acknowledgedCompletionIDs = previous?.acknowledgedCompletionIDs
                    // Legacy imports establish a baseline without exporting old local checks.
                    if canonical.measurement == .checkbox,
                       previous?.remoteCompletion != nil,
                       link.completionChanges?.isEmpty != false {
                        canonical.actualProgress = task.isCompleted ? 1 : 0
                        canonical.status = task.isCompleted ? .completed : .active
                        canonical.completedAt = task.isCompleted
                            ? (task.completedAt ?? canonical.completedAt ?? now) : nil
                    }
                    link.remoteCompletion = task.isCompleted
                    canonical.externalTaskLinkRawValue = try link.encoded()
                    canonical.updatedAt = now
                    result.updated += 1
                } else if !task.isCompleted {
                    let todo = Todo(
                        title: task.title.trimmingCharacters(in: .whitespacesAndNewlines),
                        notes: task.notes,
                        area: area,
                        habitOccurrence: false,
                        measurement: .checkbox,
                        scheduledDate: nil,
                        deadline: task.dueDate,
                        sortIndex: nextSortIndex,
                        createdAt: now,
                        updatedAt: now
                    )
                    link.remoteCompletion = task.isCompleted
                    todo.externalTaskLinkRawValue = try link.encoded()
                    modelContext.insert(todo)
                    journal.inserted.append(todo)
                    existing[link.identity] = [LinkedTodo(todo: todo, link: link)]
                    nextSortIndex -= 1
                    result.inserted += 1
                } else {
                    result.skipped += 1
                }
            }
            if repaired || result.inserted > 0 || result.updated > 0 {
                try save(modelContext)
            }
            return result
        } catch {
            journal.restore(modelContext: modelContext)
            throw error
        }
    }

    /// Safe to repeat after CloudKit imports, even when no connector is connected
    /// on this device. Late-arriving Flow relationships are reattached as well.
    @discardableResult
    func reconcileDuplicates(modelContext: ModelContext, now: Date = .now) throws -> Bool {
        let journal = MutationJournal(modelContext: modelContext)
        do {
            let linked = try linkedTodos(modelContext.fetch(FetchDescriptor<Todo>()))
            let changed = try reconcile(linked, modelContext: modelContext, journal: journal, now: now)
            if changed { try save(modelContext) }
            return changed
        } catch {
            journal.restore(modelContext: modelContext)
            throw error
        }
    }

    private struct LinkedTodo {
        let todo: Todo
        let link: ExternalTaskLink
    }

    private func linkedTodos(_ todos: [Todo]) throws -> [LinkedTodo] {
        try todos.compactMap { todo in
            guard let value = todo.externalTaskLinkRawValue else { return nil }
            // Identity corruption must fail visibly rather than allow a second
            // import of an existing task under a fresh local UUID.
            return LinkedTodo(todo: todo, link: try ExternalTaskLink.decode(value))
        }
    }

    private func reconcile(
        _ linked: [LinkedTodo],
        modelContext: ModelContext,
        journal: MutationJournal,
        now: Date
    ) throws -> Bool {
        let groups = Dictionary(grouping: linked, by: { $0.link.identity }).values
            .filter { $0.count > 1 }
        guard !groups.isEmpty else { return false }
        let sessions = try modelContext.fetch(FetchDescriptor<FlowSession>())
        let segments = try modelContext.fetch(FetchDescriptor<FlowSegment>())
        var changed = false

        for group in groups {
            let roots = group.filter { $0.link.supersededByTodoID == nil }
                .sorted { canonicalOrder($0.todo, $1.todo) }
            // A sync batch may contain only a superseded row. Wait for its
            // canonical record instead of resurrecting the tombstone.
            guard let root = roots.first else { continue }
            let canonical = root.todo
            let duplicates = group.filter { $0.todo.id != canonical.id }
            let newDuplicates = roots.dropFirst().map(\.todo)
            let duplicateIDs = Set(duplicates.map { $0.todo.id })
            var groupChanged = false

            journal.capture(canonical)
            if !newDuplicates.isEmpty {
                mergeLocalState(from: newDuplicates, into: canonical, now: now)
                // Identity and local work stay with the oldest Todo, while
                // source-owned fields follow the latest successful import.
                if let latest = roots.sorted(by: latestExternalSnapshotFirst).first,
                   latest.todo.id != canonical.id {
                    canonical.title = latest.todo.title
                    canonical.deadline = latest.todo.deadline
                    var link = latest.link
                    link.supersededByTodoID = nil
                    canonical.externalTaskLinkRawValue = try link.encoded()
                }
                var mergedLink = canonical.externalTaskLink ?? roots[0].link
                let acknowledgements = Set(roots.flatMap { $0.link.acknowledgedCompletionIDs ?? [] })
                var seenChanges = Set<UUID>()
                let allChanges: [ConnectorCompletionChange] = roots.flatMap { $0.link.completionChanges ?? [] }
                let pendingChanges = allChanges.filter {
                    !acknowledgements.contains($0.id) && seenChanges.insert($0.id).inserted
                }
                let changes = pendingChanges.sorted { left, right in
                    if left.createdAt == right.createdAt { return left.id.uuidString < right.id.uuidString }
                    return left.createdAt < right.createdAt
                }
                mergedLink.acknowledgedCompletionIDs = acknowledgements.sorted { $0.uuidString < $1.uuidString }
                mergedLink.completionChanges = changes
                canonical.externalTaskLinkRawValue = try mergedLink.encoded()
                if canonical.measurement == .checkbox, let latest = changes.last {
                    canonical.actualProgress = latest.isCompleted ? 1 : 0
                    canonical.status = latest.isCompleted ? .completed : .active
                    canonical.completedAt = latest.isCompleted ? latest.createdAt : nil
                } else if canonical.measurement == .checkbox,
                          let latest = roots.sorted(by: latestExternalSnapshotFirst).first,
                          let completed = latest.link.remoteCompletion {
                    canonical.actualProgress = completed ? 1 : 0
                    canonical.status = completed ? .completed : .active
                    canonical.completedAt = completed ? (latest.todo.completedAt ?? now) : nil
                }
                groupChanged = true
            }
            for session in sessions where session.todo.map({ duplicateIDs.contains($0.id) }) == true {
                journal.capture(session)
                session.todo = canonical
                session.updatedAt = now
                groupChanged = true
            }
            for segment in segments where segment.todo.map({ duplicateIDs.contains($0.id) }) == true {
                journal.capture(segment)
                segment.todo = canonical
                groupChanged = true
            }
            for duplicate in duplicates {
                if duplicate.link.supersededByTodoID != canonical.id || !duplicate.todo.isDeleted {
                    journal.capture(duplicate.todo)
                    var link = duplicate.link
                    link.supersededByTodoID = canonical.id
                    duplicate.todo.externalTaskLinkRawValue = try link.encoded()
                    duplicate.todo.softDelete(now: now)
                    groupChanged = true
                }
            }
            if groupChanged {
                // The established reconciler rebuilds measured progress from
                // distinct persisted sessions/segments; cached counters cannot
                // safely be added across two CloudKit copies.
                let archivedAt = canonical.archivedAt
                let wasArchived = canonical.isArchived
                try FlowProgressReconciler().reconcile(
                    todos: [canonical],
                    areas: [],
                    modelContext: modelContext,
                    now: now
                )
                if wasArchived {
                    canonical.status = .archived
                    canonical.archivedAt = archivedAt
                }
                if canonical.measurement == .checkbox {
                    let credited = sessions.filter {
                        $0.status == .completed || $0.status == .breakTime || $0.status == .awaitingResult
                    }.reduce(0) { total, session in
                        if session.resolvedSegments.isEmpty {
                            return total + (session.todo?.id == canonical.id ? session.resolvedActualFocusDurationSeconds : 0)
                        }
                        return total + session.resolvedSegments.filter { $0.todo?.id == canonical.id }
                            .reduce(0) { $0 + $1.resolvedFocusSeconds }
                    }
                    canonical.recordedFocusSeconds = max(canonical.recordedFocusSeconds, credited)
                }
                canonical.updatedAt = now
                changed = true
            }
        }
        return changed
    }

    private func mergeLocalState(from duplicates: [Todo], into canonical: Todo, now: Date) {
        let all = [canonical] + duplicates.sorted { canonicalOrder($0, $1) }
        var seenNotes = Set<String>()
        let notes = all.compactMap(\.notes).filter { !$0.isEmpty && seenNotes.insert($0).inserted }
        if !notes.isEmpty { canonical.notes = notes.joined(separator: "\n\n") }
        canonical.hashtags = all.flatMap(\.hashtags)
        canonical.actualProgress = all.map(\.actualProgress).max() ?? canonical.actualProgress
        canonical.recordedFocusSeconds = all.map(\.recordedFocusSeconds).max() ?? canonical.recordedFocusSeconds
        if canonical.area == nil { canonical.area = all.compactMap(\.area).first }
        if canonical.scheduledDate == nil { canonical.scheduledDate = all.compactMap(\.scheduledDate).first }
        if canonical.measurement == .checkbox,
           let measured = all.first(where: { $0.measurement != .checkbox }) {
            canonical.measurement = measured.measurement
            canonical.plannedAmount = measured.plannedAmount
        }
        if canonical.measurement == .checkbox, all.contains(where: \.isCompleted) {
            canonical.actualProgress = 1
            canonical.status = .completed
            canonical.completedAt = all.compactMap(\.completedAt).min() ?? now
        }
        // A user deletion/archive on either device wins over an offline import.
        if let deletedAt = all.compactMap(\.deletedAt).min() { canonical.deletedAt = deletedAt }
        if all.contains(where: \.isArchived) {
            canonical.archive(now: all.compactMap(\.archivedAt).min() ?? now)
        }
        canonical.updatedAt = now
    }

    /// SwiftData rollback clears persistence changes, but a failed synchronous
    /// write can leave values cached in already-retained model instances.
    /// Restore the fields this operation touched before rolling back a clean
    /// context; an existing editor's pending changes must never be discarded.
    private final class MutationJournal {
        private let hadPendingChanges: Bool
        private var restorations: [MutationKey: () -> Void] = [:]
        var inserted: [Todo] = []

        init(modelContext: ModelContext) {
            modelContext.processPendingChanges()
            hadPendingChanges = modelContext.hasChanges
        }

        func capture(_ todo: Todo) {
            remember(todo, \.title)
            remember(todo, \.notes)
            remember(todo, \.hashtagsRawValue)
            remember(todo, \.direction)
            remember(todo, \.measurementRawValue)
            remember(todo, \.plannedAmount)
            remember(todo, \.actualProgress)
            remember(todo, \.focusDurationSeconds)
            remember(todo, \.statusRawValue)
            remember(todo, \.completedAt)
            remember(todo, \.scheduledDate)
            remember(todo, \.deadline)
            remember(todo, \.archivedAt)
            remember(todo, \.deletedAt)
            remember(todo, \.updatedAt)
            remember(todo, \.externalTaskLinkRawValue)
        }

        func capture(_ session: FlowSession) {
            remember(session, \.todo)
            remember(session, \.updatedAt)
        }

        func capture(_ segment: FlowSegment) {
            remember(segment, \.todo)
        }

        func restore(modelContext: ModelContext) {
            guard !restorations.isEmpty || !inserted.isEmpty else { return }
            for restore in restorations.values { restore() }
            for todo in inserted { modelContext.delete(todo) }
            modelContext.processPendingChanges()
            if !hadPendingChanges { modelContext.rollback() }
        }

        private func remember<Model: AnyObject, Value>(
            _ model: Model,
            _ keyPath: ReferenceWritableKeyPath<Model, Value>
        ) {
            let key = MutationKey(model: ObjectIdentifier(model), property: keyPath)
            guard restorations[key] == nil else { return }
            let original = model[keyPath: keyPath]
            restorations[key] = { model[keyPath: keyPath] = original }
        }

        private struct MutationKey: Hashable {
            let model: ObjectIdentifier
            let property: AnyKeyPath
        }
    }

    private func latestExternalSnapshotFirst(_ lhs: LinkedTodo, _ rhs: LinkedTodo) -> Bool {
        if lhs.link.lastSyncedAt != rhs.link.lastSyncedAt {
            return lhs.link.lastSyncedAt > rhs.link.lastSyncedAt
        }
        return lhs.todo.id.uuidString < rhs.todo.id.uuidString
    }

    private func canonicalOrder(_ lhs: Todo, _ rhs: Todo) -> Bool {
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
