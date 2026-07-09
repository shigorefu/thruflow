//
//  DirectionListView.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/08.
//

import SwiftData
import SwiftUI

struct DirectionListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Direction.sortIndex, order: .forward) private var directions: [Direction]

    @State private var isShowingAddSheet = false
    @State private var editingDirectionID: UUID?
    @State private var showingArchived = false

    private var visibleDirections: [Direction] {
        directions
            .filter { !DefaultDirections.isTaskInbox($0) }
            .filter { showingArchived ? $0.isArchived : !$0.isArchived }
            .sorted(by: directionSort)
    }

    private var directionGroups: [DirectionGroup] {
        DirectionGroup.groups(for: visibleDirections)
    }

    private var editingDirection: Direction? {
        guard let editingDirectionID else { return nil }
        return directions.first { $0.id == editingDirectionID }
    }

    var body: some View {
        List {
            if visibleDirections.isEmpty {
                ContentUnavailableView(
                    showingArchived ? "アーカイブ済みの方向はありません" : "方向はまだありません",
                    systemImage: showingArchived ? "archivebox" : "point.3.connected.trianglepath.dotted",
                    description: Text(showingArchived ? "アーカイブした方向がここに表示されます。" : "進捗に変えたい領域を最初に作成しましょう。")
                )
                .listRowSeparator(.hidden)
            } else {
                ForEach(directionGroups) { group in
                    Section {
                        ForEach(group.directions) { direction in
                            DirectionRow(direction: direction)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingDirectionID = direction.id
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    if !direction.isArchived {
                                        Button("アーカイブ", systemImage: "archivebox", role: .destructive) {
                                            direction.archive()
                                            try? modelContext.save()
                                        }
                                    }
                                }
                        }
                        .onMove { source, destination in
                            moveDirections(in: group.type, from: source, to: destination)
                        }
                    } header: {
                        DirectionSectionHeader(group: group)
                    }
                    .listSectionSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
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

    private func moveDirections(in type: DirectionType, from source: IndexSet, to destination: Int) {
        var reordered = visibleDirections.filter { $0.type == type }
        reordered.move(fromOffsets: source, toOffset: destination)

        let groupedDirections = Dictionary(grouping: visibleDirections) { direction in
            direction.type
        }
        let orderedDirections = DirectionGroup.defaultOrder.flatMap { groupType -> [Direction] in
            groupType == type ? reordered : groupedDirections[groupType] ?? []
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
        DirectionGroup.defaultOrder.firstIndex(of: type) ?? DirectionGroup.defaultOrder.count
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
        .listRowInsets(EdgeInsets(top: 3, leading: 10, bottom: 3, trailing: 10))
        .listRowSeparator(.hidden)
        .listRowBackground(rowBackground)
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

    static let defaultOrder: [DirectionType] = [.habit, .neutral, .nice]

    var title: String {
        type.displayName
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

    static func groups(for directions: [Direction]) -> [DirectionGroup] {
        defaultOrder.compactMap { type in
            let items = directions.filter { $0.type == type }
            guard !items.isEmpty else { return nil }
            return DirectionGroup(type: type, directions: items)
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
        }
        .padding(.top, 12)
        .padding(.bottom, 4)
        .textCase(nil)
    }
}

#Preview {
    DirectionListView()
        .modelContainer(for: [Direction.self, Todo.self, FlowSession.self], inMemory: true)
}
