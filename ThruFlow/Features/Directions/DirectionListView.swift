//
//  DirectionListView.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/08.
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct DirectionListView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("directionKanbanColumnOrder") private var directionGroupOrderRaw = DirectionGroupOrder.encode(DirectionGroupOrder.defaultValue)

    @Query(sort: \Direction.sortIndex, order: .forward) private var directions: [Direction]

    @State private var isShowingAddSheet = false
    @State private var editingDirectionID: UUID?
    @State private var showingArchived = false
    @State private var draggedDirectionID: UUID?
    @State private var dropTargetID: UUID?
    @State private var draggedGroupType: DirectionType?
    @State private var dropTargetGroupType: DirectionType?

    private var visibleDirections: [Direction] {
        directions
            .filter { !DefaultDirections.isTaskInbox($0) }
            .filter { showingArchived ? $0.isArchived : !$0.isArchived }
            .sorted(by: directionSort)
    }

    private var directionGroups: [DirectionGroup] {
        DirectionGroup.groups(for: visibleDirections, order: directionGroupOrder)
    }

    private var directionGroupOrder: [DirectionType] {
        DirectionGroup.order(from: directionGroupOrderRaw)
    }

    private var editingDirection: Direction? {
        guard let editingDirectionID else { return nil }
        return directions.first { $0.id == editingDirectionID }
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(directionGroups) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        DirectionSectionHeader(group: group)
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
                                    object: "direction-group:\(group.type.rawValue)" as NSString
                                )
                            }

                        ScrollView(.vertical) {
                            LazyVStack(spacing: 8) {
                                if group.directions.isEmpty {
                                    ContentUnavailableView(
                                        "方向はありません",
                                        systemImage: "tray",
                                        description: Text("この列に該当する方向はまだありません。")
                                    )
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 40)
                                }

                                ForEach(group.directions) { direction in
                                    DirectionRow(direction: direction)
                                        .contentShape(Rectangle())
                                        .overlay {
                                            if dropTargetID == direction.id {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .strokeBorder(Color.accentColor, lineWidth: 2)
                                            }
                                        }
                                        .onTapGesture {
                                            editingDirectionID = direction.id
                                        }
                                        .onDrag {
                                            draggedDirectionID = direction.id
                                            return NSItemProvider(object: direction.id.uuidString as NSString)
                                        }
                                        .onDrop(
                                            of: [UTType.text],
                                            delegate: DirectionReorderDropDelegate(
                                                targetID: direction.id,
                                                draggedDirectionID: $draggedDirectionID,
                                                dropTargetID: $dropTargetID,
                                                move: moveDirection
                                            )
                                        )
                                        .contextMenu {
                                            if !direction.isArchived {
                                                Button("アーカイブ", systemImage: "archivebox", role: .destructive) {
                                                    direction.archive()
                                                    try? modelContext.save()
                                                }
                                            }
                                        }
                                }
                            }
                            .padding(.bottom, 8)
                        }
                        .scrollIndicators(.visible)
                    }
                    .frame(width: 320)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(12)
                    .background(Color.primary.opacity(0.035))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onDrop(
                        of: [UTType.text],
                        delegate: DirectionGroupReorderDropDelegate(
                            targetType: group.type,
                            draggedGroupType: $draggedGroupType,
                            dropTargetGroupType: $dropTargetGroupType,
                            move: moveDirectionGroup
                        )
                    )
                }
            }
            .padding(16)
        }
        .scrollIndicators(.visible)
        .animation(.default, value: visibleDirections.map(\.id))
        .navigationTitle("方向")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isShowingAddSheet = true
                } label: {
                    Label("方向を追加", systemImage: "plus")
                }
            }

            ToolbarItem {
                Toggle(isOn: $showingArchived) {
                    Label("アーカイブ", systemImage: "archivebox")
                }
                .toggleStyle(.button)
            }
        }
        .onAppear(perform: normalizeSortIndexesIfNeeded)
        .sheet(isPresented: $isShowingAddSheet) {
            DirectionFormView(mode: .create)
        }
        .sheet(
            isPresented: Binding(
                get: { editingDirectionID != nil },
                set: { if !$0 { editingDirectionID = nil } }
            )
        ) {
            if let editingDirection {
                DirectionFormView(mode: .edit(editingDirection))
            }
        }
    }

    private func moveDirection(_ sourceID: UUID, _ targetID: UUID) {
        guard sourceID != targetID,
              let sourceDirection = visibleDirections.first(where: { $0.id == sourceID }),
              let targetDirection = visibleDirections.first(where: { $0.id == targetID }),
              sourceDirection.type == targetDirection.type else { return }

        var reordered = visibleDirections.filter { $0.type == sourceDirection.type }
        guard let sourceIndex = reordered.firstIndex(where: { $0.id == sourceID }),
              let originalTargetIndex = reordered.firstIndex(where: { $0.id == targetID }) else { return }

        let movedDirection = reordered.remove(at: sourceIndex)
        guard let targetIndex = reordered.firstIndex(where: { $0.id == targetID }) else { return }
        let insertionIndex = sourceIndex < originalTargetIndex ? targetIndex + 1 : targetIndex
        reordered.insert(movedDirection, at: insertionIndex)

        let groupedDirections = Dictionary(grouping: visibleDirections) { direction in
            direction.type
        }
        let orderedDirections = directionGroupOrder.flatMap { groupType -> [Direction] in
            groupType == sourceDirection.type ? reordered : groupedDirections[groupType] ?? []
        }

        for (index, direction) in orderedDirections.enumerated() {
            direction.setSortIndex(index)
        }

        try? modelContext.save()
    }

    private func normalizeSortIndexesIfNeeded() {
        let activeDirections = directions.filter { !$0.isArchived && !DefaultDirections.isTaskInbox($0) }
        let hasDuplicateIndexes = Set(activeDirections.map(\.sortIndex)).count != activeDirections.count

        guard hasDuplicateIndexes else { return }

        let orderedDirections = activeDirections.sorted { lhs, rhs in
            if lhs.type != rhs.type {
                return typeOrder(lhs.type) < typeOrder(rhs.type)
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }

        for (index, direction) in orderedDirections.enumerated() {
            direction.setSortIndex(index)
        }

        try? modelContext.save()
    }

    private func directionSort(_ lhs: Direction, _ rhs: Direction) -> Bool {
        if lhs.sortIndex != rhs.sortIndex {
            return lhs.sortIndex < rhs.sortIndex
        }

        if lhs.type != rhs.type {
            return typeOrder(lhs.type) < typeOrder(rhs.type)
        }

        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }

    private func typeOrder(_ type: DirectionType) -> Int {
        directionGroupOrder.firstIndex(of: type) ?? directionGroupOrder.count
    }

    private func moveDirectionGroup(_ sourceType: DirectionType, _ targetType: DirectionType) {
        guard sourceType != targetType else { return }

        let reordered = DirectionGroupOrder.moving(
            sourceType,
            relativeTo: targetType,
            in: directionGroupOrder
        )
        directionGroupOrderRaw = DirectionGroupOrder.encode(reordered)
    }
}

private struct DirectionReorderDropDelegate: DropDelegate {
    let targetID: UUID
    @Binding var draggedDirectionID: UUID?
    @Binding var dropTargetID: UUID?
    let move: (UUID, UUID) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        draggedDirectionID != nil
    }

    func dropEntered(info: DropInfo) {
        guard let draggedDirectionID, draggedDirectionID != targetID else { return }
        dropTargetID = targetID
        withAnimation(.easeInOut(duration: 0.16)) {
            move(draggedDirectionID, targetID)
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
        draggedDirectionID = nil
        dropTargetID = nil
        return true
    }
}

private struct DirectionGroupReorderDropDelegate: DropDelegate {
    let targetType: DirectionType
    @Binding var draggedGroupType: DirectionType?
    @Binding var dropTargetGroupType: DirectionType?
    let move: (DirectionType, DirectionType) -> Void

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

private struct DirectionRow: View {
    let direction: Direction

    var body: some View {
        HStack(spacing: 12) {
            Text(direction.symbolName)
                .font(.title2)
                .frame(width: 36, height: 36)
                .background(Color(hex: direction.colorHex).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(direction.name)
                        .font(.headline)

                    Text(direction.type.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: direction.isArchived ? "archivebox" : "line.3.horizontal")
                .foregroundStyle(.secondary)
                .accessibilityLabel(direction.isArchived ? "アーカイブ済み" : "並び替え")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(rowBackground)
    }

    private var summary: String {
        guard
            let target = direction.goalTarget,
            let period = direction.goalPeriod,
            let unit = direction.goalUnit
        else {
            return direction.type.description
        }

        return "\(target) \(unit.displayName.lowercased()) \(period.displayName.lowercased())"
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(hex: direction.colorHex).opacity(direction.isArchived ? 0.04 : 0.08))
            .padding(.vertical, 2)
    }
}

private struct DirectionGroup: Identifiable {
    let type: DirectionType
    let directions: [Direction]

    var id: String { type.rawValue }

    static func order(from rawValue: String) -> [DirectionType] {
        DirectionGroupOrder.decode(rawValue)
    }

    var title: String {
        switch type {
        case .neutral: "通常"
        case .habit: "習慣"
        case .nice: "ナイス"
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

    static func groups(for directions: [Direction], order: [DirectionType]) -> [DirectionGroup] {
        order.map { type in
            DirectionGroup(
                type: type,
                directions: directions.filter { $0.type == type }
            )
        }
    }
}

private struct DirectionSectionHeader: View {
    let group: DirectionGroup

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(group.tint)
                .frame(width: 7, height: 7)

            Text(group.title)
                .font(.caption.weight(.semibold))

            Text("\(group.directions.count)")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.12))
                .clipShape(Capsule())

            Spacer(minLength: 0)

            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.secondary)
                .accessibilityLabel("グループを並び替え")
        }
        .padding(.vertical, 4)
        .textCase(nil)
    }
}

#Preview {
    DirectionListView()
        .modelContainer(for: [Direction.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self], inMemory: true)
}
