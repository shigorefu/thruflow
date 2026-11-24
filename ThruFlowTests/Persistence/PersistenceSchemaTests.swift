import Foundation
import SwiftData
import Testing
@testable import ThruFlow

@MainActor
struct PersistenceSchemaTests {
    @Test func developmentAndProductionUseDifferentPersistentStores() {
        #expect(
            AppModelContainerFactory.storeFilename(for: .development) ==
                "default-development.store"
        )
        #expect(
            AppModelContainerFactory.storeFilename(for: .production) ==
                "default.store"
        )
        #expect(
            AppModelContainerFactory.storeFilename(for: .development) !=
                AppModelContainerFactory.storeFilename(for: .production)
        )
    }

    @Test func simulatorUsesLocalStoreWithoutCloudKitEntitlement() {
        #expect(
            !AppModelContainerFactory.shouldUseCloudKit(
                isRunningTests: false,
                isCloudKitDisabled: false,
                isRunningInSimulator: true,
                hasCloudKitEntitlement: true
            )
        )
        #expect(
            AppModelContainerFactory.shouldUseCloudKit(
                isRunningTests: false,
                isCloudKitDisabled: false,
                isRunningInSimulator: false,
                hasCloudKitEntitlement: true
            )
        )
    }

    @Test func unsignedBuildUsesLocalStoreWithoutCloudKitEntitlement() {
        #expect(
            !AppModelContainerFactory.shouldUseCloudKit(
                isRunningTests: false,
                isCloudKitDisabled: false,
                isRunningInSimulator: false,
                hasCloudKitEntitlement: false
            )
        )
    }

    @Test func areaCodeNameKeepsDirectionPersistenceIdentity() throws {
        let schema = AppModelContainerFactory.schema
        let entityNames = Set(schema.entities.map(\.name))

        #expect(entityNames.contains("Direction"))
        #expect(!entityNames.contains("Area"))

        let todoEntity = try #require(schema.entities.first { $0.name == "Todo" })
        let sessionEntity = try #require(schema.entities.first { $0.name == "FlowSession" })
        let segmentEntity = try #require(schema.entities.first { $0.name == "FlowSegment" })

        #expect(todoEntity.properties.contains { $0.name == "direction" })
        #expect(sessionEntity.properties.contains { $0.name == "direction" })
        #expect(segmentEntity.properties.contains { $0.name == "direction" })
        #expect(!todoEntity.properties.contains { $0.name == "area" })
        #expect(!sessionEntity.properties.contains { $0.name == "area" })
        #expect(!segmentEntity.properties.contains { $0.name == "area" })
    }

    @Test func sharedSchemaPersistsCloudKitCompatibleRelationships() throws {
        let container = AppModelContainerFactory.make()
        let context = ModelContext(container)
        let area = Area(name: "仕事", type: .neutral)
        let todo = Todo(title: "資料を作る", area: area)
        let startedAt = Date(timeIntervalSince1970: 10_000)
        let session = FlowSession(
            area: area,
            todo: todo,
            mode: .twentyFiveFive,
            startedAt: startedAt,
            plannedEndAt: startedAt.addingTimeInterval(25 * 60),
            plannedFocusDurationSeconds: 25 * 60,
            plannedBreakDurationSeconds: 5 * 60
        )
        let segment = FlowSegment(
            session: session,
            area: area,
            todo: todo,
            startedAt: startedAt,
            startFocusSeconds: 0
        )
        session.segments = [segment]

        context.insert(area)
        context.insert(todo)
        context.insert(session)
        try context.save()

        #expect(area.todos?.map(\.id).contains(todo.id) == true)
        #expect(area.flowSessions?.map(\.id).contains(session.id) == true)
        #expect(todo.flowSessions?.map(\.id).contains(session.id) == true)
        #expect(session.resolvedSegments.map(\.id) == [segment.id])
    }
}
