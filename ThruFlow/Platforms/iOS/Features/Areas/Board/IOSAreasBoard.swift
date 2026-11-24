#if os(iOS)
import SwiftUI

struct IOSAreasBoard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var minimumGroupWidth = 240.0

    let groupOrder: [AreaType]
    let records: IOSAreaRecords?
    let showingArchived: Bool
    let loadFailed: Bool
    let revealsInitialRows: Bool
    let onEditArea: (Area) -> Void
    let onArchiveArea: (Area, Bool) -> Void
    let onSelectProject: (Project) -> Void

    var body: some View {
        GeometryReader { geometry in
            let spacing: CGFloat = 14
            let availableWidth = max(0, geometry.size.width - 32)
            let fittedCount = Int((availableWidth + spacing) / (minimumGroupWidth + spacing))
            let columnCount = dynamicTypeSize.isAccessibilitySize ? 1 : min(3, max(1, fittedCount))
            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: spacing, alignment: .top), count: columnCount),
                    alignment: .leading,
                    spacing: spacing
                ) {
                    ForEach(Array(groupOrder.enumerated()), id: \.element) { index, type in
                        groupColumn(type, columnIndex: index)
                    }
                }
                .padding(16)
            }
        }
        .overlay {
            if records == nil { IOSAreasLoadingContent(loadFailed: loadFailed) }
        }
    }

    private func groupColumn(_ type: AreaType, columnIndex: Int) -> some View {
        let groupAreas = visibleAreas(for: type)
        return LazyVStack(alignment: .leading, spacing: 12) {
            IOSAreaGroupHeader(type: type)
            if records != nil && groupAreas.isEmpty {
                Text(showingArchived ? String(localized: "アーカイブはありません") : String(localized: "方向はありません"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
            }
            ForEach(Array(groupAreas.enumerated()), id: \.element.id) { index, area in
                IOSAreaTreeView(
                    area: area,
                    projects: records?.projectsByArea[area.id] ?? [],
                    onEditArea: onEditArea,
                    onArchiveArea: onArchiveArea,
                    onSelectProject: onSelectProject
                )
                    .featureRowReveal(index: index + columnIndex, enabled: revealsInitialRows)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
    }

    private func visibleAreas(for type: AreaType) -> [Area] {
        let groups = showingArchived ? records?.archivedGroups : records?.activeGroups
        return groups?[type] ?? []
    }
}
#endif
