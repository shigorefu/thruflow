//
//  HabitTodoReconciler.swift
//  ThruFlow
//

import Foundation

struct HabitTodoReconciliationResult {
    let changed: Bool
    let canonicalTodos: [Todo]
    let affectedAreas: [Area]
}

struct HabitTodoReconciler {
    var calendar: Calendar = .current

    func reconcile(
        todos: [Todo],
        sessions: [FlowSession],
        segments: [FlowSegment],
        now: Date = .now
    ) -> HabitTodoReconciliationResult {
        let candidates = todos.filter { todo in
            guard let area = todo.area else { return false }
            return area.type == .habit &&
                !todo.isArchived &&
                !todo.isDeleted &&
                todo.scheduledDate != nil
        }
        let groups = Dictionary(grouping: candidates, by: occurrenceKey)

        var canonicalTodos: [Todo] = []
        var affectedAreas: [Area] = []
        var changed = false

        for group in groups.values where group.count > 1 {
            let canonical = group.sorted {
                isPreferred($0, over: $1, sessions: sessions, segments: segments)
            }[0]
            let duplicates = group.filter { $0.id != canonical.id }

            merge(duplicates, into: canonical, sessions: sessions, segments: segments, now: now)
            canonicalTodos.append(canonical)
            if let area = canonical.area {
                affectedAreas.append(area)
            }
            changed = true
        }

        return HabitTodoReconciliationResult(
            changed: changed,
            canonicalTodos: unique(canonicalTodos),
            affectedAreas: unique(affectedAreas)
        )
    }

    private func occurrenceKey(_ todo: Todo) -> String {
        let areaID = todo.area?.id.uuidString ?? ""
        let day = calendar.startOfDay(for: todo.scheduledDate ?? .distantPast)
        return "\(areaID)|\(day.timeIntervalSinceReferenceDate)"
    }

    private func isPreferred(
        _ lhs: Todo,
        over rhs: Todo,
        sessions: [FlowSession],
        segments: [FlowSegment]
    ) -> Bool {
        let lhsHistoryCount = historyCount(for: lhs, sessions: sessions, segments: segments)
        let rhsHistoryCount = historyCount(for: rhs, sessions: sessions, segments: segments)
        if lhsHistoryCount != rhsHistoryCount {
            return lhsHistoryCount > rhsHistoryCount
        }
        if lhs.isCompleted != rhs.isCompleted {
            return lhs.isCompleted
        }
        let lhsHasTitle = !lhs.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let rhsHasTitle = !rhs.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if lhsHasTitle != rhsHasTitle {
            return lhsHasTitle
        }
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private func historyCount(
        for todo: Todo,
        sessions: [FlowSession],
        segments: [FlowSegment]
    ) -> Int {
        sessions.filter { $0.todo?.id == todo.id }.count +
            segments.filter { $0.todo?.id == todo.id }.count
    }

    private func merge(
        _ duplicates: [Todo],
        into canonical: Todo,
        sessions: [FlowSession],
        segments: [FlowSegment],
        now: Date
    ) {
        let allTodos = [canonical] + duplicates
        let completedAt = allTodos.compactMap(\.completedAt).min()
        let bestTitle = allTodos
            .map(\.title)
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let bestNotes = allTodos.compactMap(\.notes).first
        let hashtags = allTodos.flatMap(\.hashtags)
        let maximumProgress = allTodos.map(\.actualProgress).max() ?? 0
        let maximumFocusSeconds = allTodos.map(\.recordedFocusSeconds).max() ?? 0

        if canonical.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            canonical.title = bestTitle ?? ""
        }
        if canonical.notes == nil {
            canonical.notes = bestNotes
        }
        canonical.hashtags = hashtags
        canonical.actualProgress = maximumProgress
        canonical.recordedFocusSeconds = maximumFocusSeconds
        canonical.sortIndex = allTodos.map(\.sortIndex).min() ?? canonical.sortIndex
        canonical.createdAt = allTodos.map(\.createdAt).min() ?? canonical.createdAt
        canonical.scheduledDate = canonical.scheduledDate.map(calendar.startOfDay(for:))

        if canonical.measurement == .checkbox, completedAt != nil {
            canonical.setCompleted(true, now: completedAt ?? now)
        } else if canonical.measurement != .checkbox {
            canonical.setProgress(maximumProgress, now: now)
        }

        let duplicateIDs = Set(duplicates.map(\.id))
        for session in sessions where session.todo.map({ duplicateIDs.contains($0.id) }) == true {
            session.todo = canonical
            session.updatedAt = now
        }
        for segment in segments where segment.todo.map({ duplicateIDs.contains($0.id) }) == true {
            segment.todo = canonical
        }
        for duplicate in duplicates {
            duplicate.softDelete(now: now)
        }
        canonical.updatedAt = now
    }

    private func unique<Model: AnyObject & Identifiable>(_ models: [Model]) -> [Model] where Model.ID == UUID {
        var seen = Set<UUID>()
        return models.filter { seen.insert($0.id).inserted }
    }
}
