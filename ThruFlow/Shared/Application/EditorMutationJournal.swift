import Foundation
import SwiftData

/// Restores editor-owned changes in retained models as well as the context.
/// SwiftData on macOS 26 can leave cached model properties unchanged by rollback.
@MainActor
final class EditorMutationJournal {
    private let hadPendingChanges: Bool
    private let originalInsertions: Set<ObjectIdentifier>
    private var restorations: [MutationKey: () -> Void] = [:]

    init(modelContext: ModelContext) {
        modelContext.processPendingChanges()
        hadPendingChanges = modelContext.hasChanges
        originalInsertions = Set(modelContext.insertedModelsArray.map { ObjectIdentifier($0) })
    }

    func capture(_ todo: Todo) {
        remember(todo, \.title)
        remember(todo, \.notes)
        remember(todo, \.hashtagsRawValue)
        remember(todo, \.direction)
        remember(todo, \.project)
        remember(todo, \.measurementRawValue)
        remember(todo, \.priorityRawValue)
        remember(todo, \.isRoomIfPossible)
        remember(todo, \.plannedAmount)
        remember(todo, \.actualProgress)
        remember(todo, \.statusRawValue)
        remember(todo, \.completedAt)
        remember(todo, \.scheduledDate)
        remember(todo, \.scheduledTimeMinutes)
        remember(todo, \.reminderEnabled)
        remember(todo, \.scheduledTimeUpdatedAt)
        remember(todo, \.deadline)
        remember(todo, \.deletedAt)
        remember(todo, \.updatedAt)
        // Todo.update can enqueue completion changes for connected Tasks.
        remember(todo, \.externalTaskLinkRawValue)
    }

    func capture(_ area: Area) {
        remember(area, \.name)
        remember(area, \.typeRawValue)
        remember(area, \.symbolName)
        remember(area, \.colorHex)
        remember(area, \.goalTarget)
        remember(area, \.goalPeriodRawValue)
        remember(area, \.goalUnitRawValue)
        remember(area, \.goalScheduleRawValue)
        remember(area, \.weeklyTargetCount)
        remember(area, \.weekdayMask)
        remember(area, \.updatedAt)
        remember(area, \.archivedAt)
        remember(area, \.habitPausePeriodsRawValue)
    }

    func capture(_ project: Project) {
        remember(project, \.name)
        remember(project, \.notes)
        remember(project, \.completedAt)
        remember(project, \.updatedAt)
    }

    func restore(modelContext: ModelContext) {
        // Capture the delta before restoring relationships. Keep insertions that
        // belonged to an already-open editor or another pending operation.
        let inserted = modelContext.insertedModelsArray.filter {
            !originalInsertions.contains(ObjectIdentifier($0))
        }
        for restore in restorations.values { restore() }
        if hadPendingChanges {
            // A whole-context rollback would discard unrelated user changes.
            for model in inserted { modelContext.delete(model) }
            modelContext.processPendingChanges()
        } else {
            // Rollback already removes insertions. Deleting them first can
            // leave inverse-relationship changes pending after rollback.
            modelContext.processPendingChanges()
            modelContext.rollback()
        }
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
