import Foundation
import SwiftData
import Testing
@testable import ThruFlow

@MainActor
struct StatisticsDemoDataTests {
    @Test func demoFixtureIsCompleteAndDoesNotDuplicateOnReseeding() throws {
        let container = try ModelContainer(for: AppModelContainerFactory.schema,
            configurations: ModelConfiguration(schema: AppModelContainerFactory.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = container.mainContext
        try StatisticsDemoData.seed(modelContext: context)
        try StatisticsDemoData.seed(modelContext: context)
        #expect(try context.fetchCount(FetchDescriptor<Area>()) == 3)
        #expect(try context.fetchCount(FetchDescriptor<Todo>()) == 24)
        let sessions = try context.fetch(FetchDescriptor<FlowSession>())
        #expect(sessions.count == 21)
        #expect(sessions.allSatisfy { $0.resolvedSegments.count == 1 && $0.resolvedActualFocusDurationSeconds > 0 })
        #expect(sessions.allSatisfy { $0.endedAt! < .now })
        #expect(try context.fetch(FetchDescriptor<Todo>()).contains { $0.measurement == .minutes && $0.status == .completed })
    }

    @Test func demoFixtureDoesNotPopulateAnExistingWorkspace() throws {
        let container = try ModelContainer(for: AppModelContainerFactory.schema,
            configurations: ModelConfiguration(schema: AppModelContainerFactory.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        container.mainContext.insert(Area(name: "Existing", type: .neutral))
        try container.mainContext.save()
        try StatisticsDemoData.seed(modelContext: container.mainContext)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Area>()) == 1)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<FlowSession>()) == 0)
    }
}
