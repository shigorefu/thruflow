#if os(iOS)
import SwiftData
import SwiftUI

struct IOSStatisticsAreaQuery: View {
    @Query(sort: \Area.updatedAt, order: .reverse) private var areas: [Area]
    let onUpdate: ([Area]) -> Void

    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .task(id: areas.map { Revision(id: $0.id, updatedAt: $0.updatedAt) }) {
                guard !Task.isCancelled else { return }
                onUpdate(areas)
            }
    }

    private struct Revision: Hashable {
        let id: UUID
        let updatedAt: Date
    }
}
#endif
