//
//  AreaListView.swift
//  ThruFlow
//
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct AreaListView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("directionKanbanColumnOrder") private var areaGroupOrderRaw = AreaGroupOrder.encode(AreaGroupOrder.defaultValue)

    @Query(sort: \Area.sortIndex, order: .forward) private var areas: [Area]

    @State private var isShowingAddSheet = false
    @State private var editingAreaID: UUID?
    @State private var showingArchived = false
    @State private var draggedAreaID: UUID?
    @State private var dropTargetID: UUID?
    @State private var draggedGroupType: AreaType?
    @State private var dropTargetGroupType: AreaType?

    private var visibleAreas: [Area] {
        areas
            .filter { !DefaultAreas.isTaskInbox($0) }
            .filter { showingArchived ? $0.isArchived : !$0.isArchived }
            .sorted(by: areaSort)
    }

    private var areaGroups: [AreaGroup] {
        AreaGroup.groups(for: visibleAreas, order: areaGroupOrder)
    }

    private var areaGroupOrder: [AreaType] {
        AreaGroup.order(from: areaGroupOrderRaw)
    }

    private var areaGridColumns: [GridItem] {
        [
            GridItem(
                .adaptive(minimum: 300),
                spacing: 14,
                alignment: .top
            )
        ]
    }

    private var editingArea: Area? {
        guard let editingAreaID else { return nil }
        return areas.first { $0.id == editingAreaID }
    }

    var body: some View {
        ScrollView(.vertical) {
            LazyVGrid(
                columns: areaGridColumns,
                alignment: .leading,
                spacing: 14
            ) {
                ForEach(areaGroups) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        AreaSectionHeader(group: group)
                            .contentShape(Rectangle())
                            .overlay {
                                if dropTargetGroupType == group.type {
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(Color.accentColor, lineWidth: 2)
                                }
                            }
                            .onDrag {
                                draggedGroupType = group.type
                                return NSItemProvider(
                                    object: "area-group:\(group.type.rawValue)" as NSString
                                )
                            }

                        LazyVStack(spacing: 8) {
                            if group.areas.isEmpty {
                                ContentUnavailableView(
                                    String(localized: "方向はありません"),
                                    systemImage: ProductSymbol.area,
                                    description: Text(String(localized: "この列に該当する方向はまだありません。"))
                                )
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                            }

                            ForEach(group.areas) { area in
                                AreaRow(area: area)
                                    .contentShape(Rectangle())
                                    .overlay {
                                        if dropTargetID == area.id {
                                            RoundedRectangle(cornerRadius: 8)
                                                .strokeBorder(Color.accentColor, lineWidth: 2)
                                        }
                                    }
                                    .onTapGesture {
                                        editingAreaID = area.id
                                    }
                                    .onDrag {
                                        draggedAreaID = area.id
                                        return NSItemProvider(object: area.id.uuidString as NSString)
                                    }
                                    .onDrop(
                                        of: [UTType.text],
                                        delegate: AreaReorderDropDelegate(
                                            targetID: area.id,
                                            draggedAreaID: $draggedAreaID,
                                            dropTargetID: $dropTargetID,
                                            move: moveArea
                                        )
                                    )
                                    .contextMenu {
                                        if !area.isArchived {
                                            Button(String(localized: "アーカイブする"), systemImage: "archivebox", role: .destructive) {
                                                area.archive()
                                                _ = modelContext.saveReporting(.areaUpdate)
                                            }
                                        }
                                    }
                            }
                        }
                        .padding(.bottom, 8)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(12)
                    .background(Color.primary.opacity(0.035))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onDrop(
                        of: [UTType.text],
                        delegate: AreaGroupReorderDropDelegate(
                            targetType: group.type,
                            draggedGroupType: $draggedGroupType,
                            dropTargetGroupType: $dropTargetGroupType,
                            move: moveAreaGroup
                        )
                    )
                }
            }
            .padding(16)
        }
        .scrollIndicators(.visible)
        .animation(.default, value: visibleAreas.map(\.id))
        .navigationTitle(String(localized: "方向"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isShowingAddSheet = true
                } label: {
                    Label(String(localized: "方向を追加"), systemImage: "plus")
                }
            }

            ToolbarItem {
                Toggle(isOn: $showingArchived) {
                    Label(String(localized: "アーカイブ"), systemImage: "archivebox")
                }
                .toggleStyle(.button)
            }
        }
        .onAppear(perform: normalizeSortIndexesIfNeeded)
        .sheet(isPresented: $isShowingAddSheet) {
            AreaFormView(mode: .create)
                .frame(width: 420)
        }
        .sheet(
            isPresented: Binding(
                get: { editingAreaID != nil },
                set: { if !$0 { editingAreaID = nil } }
            )
        ) {
            if let editingArea {
                AreaFormView(mode: .edit(editingArea))
                    .frame(width: 420)
            }
        }
    }

    private func moveArea(_ sourceID: UUID, _ targetID: UUID) {
        guard sourceID != targetID,
              let sourceArea = visibleAreas.first(where: { $0.id == sourceID }),
              let targetArea = visibleAreas.first(where: { $0.id == targetID }),
              sourceArea.type == targetArea.type else { return }

        var reordered = visibleAreas.filter { $0.type == sourceArea.type }
        guard let sourceIndex = reordered.firstIndex(where: { $0.id == sourceID }),
              let originalTargetIndex = reordered.firstIndex(where: { $0.id == targetID }) else { return }

        let movedArea = reordered.remove(at: sourceIndex)
        guard let targetIndex = reordered.firstIndex(where: { $0.id == targetID }) else { return }
        let insertionIndex = sourceIndex < originalTargetIndex ? targetIndex + 1 : targetIndex
        reordered.insert(movedArea, at: insertionIndex)

        let groupedAreas = Dictionary(grouping: visibleAreas) { area in
            area.type
        }
        let orderedAreas = areaGroupOrder.flatMap { groupType -> [Area] in
            groupType == sourceArea.type ? reordered : groupedAreas[groupType] ?? []
        }

        for (index, area) in orderedAreas.enumerated() {
            area.setSortIndex(index)
        }

        _ = modelContext.saveReporting(.areaUpdate)
    }

    private func normalizeSortIndexesIfNeeded() {
        let activeAreas = areas.filter { !$0.isArchived && !DefaultAreas.isTaskInbox($0) }
        let hasDuplicateIndexes = Set(activeAreas.map(\.sortIndex)).count != activeAreas.count

        guard hasDuplicateIndexes else { return }

        let orderedAreas = activeAreas.sorted { lhs, rhs in
            if lhs.type != rhs.type {
                return typeOrder(lhs.type) < typeOrder(rhs.type)
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }

        for (index, area) in orderedAreas.enumerated() {
            area.setSortIndex(index)
        }

        _ = modelContext.saveReporting(.areaUpdate)
    }

    private func areaSort(_ lhs: Area, _ rhs: Area) -> Bool {
        if lhs.sortIndex != rhs.sortIndex {
            return lhs.sortIndex < rhs.sortIndex
        }

        if lhs.type != rhs.type {
            return typeOrder(lhs.type) < typeOrder(rhs.type)
        }

        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }

    private func typeOrder(_ type: AreaType) -> Int {
        areaGroupOrder.firstIndex(of: type) ?? areaGroupOrder.count
    }

    private func moveAreaGroup(_ sourceType: AreaType, _ targetType: AreaType) {
        guard sourceType != targetType else { return }

        let reordered = AreaGroupOrder.moving(
            sourceType,
            relativeTo: targetType,
            in: areaGroupOrder
        )
        areaGroupOrderRaw = AreaGroupOrder.encode(reordered)
    }
}

private struct AreaReorderDropDelegate: DropDelegate {
    let targetID: UUID
    @Binding var draggedAreaID: UUID?
    @Binding var dropTargetID: UUID?
    let move: (UUID, UUID) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        draggedAreaID != nil
    }

    func dropEntered(info: DropInfo) {
        guard let draggedAreaID, draggedAreaID != targetID else { return }
        dropTargetID = targetID
        withAnimation(.easeInOut(duration: 0.16)) {
            move(draggedAreaID, targetID)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        if dropTargetID == targetID {
            dropTargetID = nil
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedAreaID = nil
        dropTargetID = nil
        return true
    }
}

private struct AreaGroupReorderDropDelegate: DropDelegate {
    let targetType: AreaType
    @Binding var draggedGroupType: AreaType?
    @Binding var dropTargetGroupType: AreaType?
    let move: (AreaType, AreaType) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        draggedGroupType != nil
    }

    func dropEntered(info: DropInfo) {
        guard let draggedGroupType, draggedGroupType != targetType else { return }
        dropTargetGroupType = targetType
        withAnimation(.easeInOut(duration: 0.16)) {
            move(draggedGroupType, targetType)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        if dropTargetGroupType == targetType {
            dropTargetGroupType = nil
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedGroupType = nil
        dropTargetGroupType = nil
        return true
    }
}

private struct AreaRow: View {
    let area: Area

    var body: some View {
        HStack(spacing: 12) {
            Text(area.symbolName)
                .font(.title2)
                .frame(width: 36, height: 36)
                .background(Color(hex: area.colorHex).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(area.name)
                        .font(.headline)

                    Text(area.type.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: area.isArchived ? "archivebox" : "line.3.horizontal")
                .foregroundStyle(.secondary)
                .accessibilityLabel(area.isArchived ? String(localized: "アーカイブ済み") : String(localized: "並び替え"))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(rowBackground)
    }

    private var summary: String {
        guard
            let target = area.goalTarget,
            let period = area.goalPeriod,
            let unit = area.goalUnit
        else {
            return area.type.description
        }

        return "\(target) \(unit.displayName.lowercased()) \(period.displayName.lowercased())"
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(hex: area.colorHex).opacity(area.isArchived ? 0.04 : 0.08))
            .padding(.vertical, 2)
    }
}

private struct AreaGroup: Identifiable {
    let type: AreaType
    let areas: [Area]

    var id: String { type.rawValue }

    static func order(from rawValue: String) -> [AreaType] {
        AreaGroupOrder.decode(rawValue)
    }

    var title: String {
        switch type {
        case .neutral: String(localized: "通常")
        case .habit: String(localized: "習慣一覧")
        case .nice: String(localized: "ナイス")
        }
    }

    var tint: Color {
        switch type {
        case .habit:
            .red
        case .neutral:
            .blue
        case .nice:
            .green
        }
    }

    static func groups(for areas: [Area], order: [AreaType]) -> [AreaGroup] {
        order.map { type in
            AreaGroup(
                type: type,
                areas: areas.filter { $0.type == type }
            )
        }
    }
}

private struct AreaSectionHeader: View {
    let group: AreaGroup

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(group.tint)
                .frame(width: 7, height: 7)

            Text(group.title)
                .font(.caption.weight(.semibold))

            Text("\(group.areas.count)")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.12))
                .clipShape(Capsule())

            Spacer(minLength: 0)

            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.secondary)
                .accessibilityLabel(String(localized: "グループを並び替え"))
        }
        .padding(.vertical, 4)
        .textCase(nil)
    }
}

#Preview {
    AreaListView()
        .modelContainer(for: [Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self], inMemory: true)
}
