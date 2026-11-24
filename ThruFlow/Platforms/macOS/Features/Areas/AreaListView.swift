//
//  AreaListView.swift
//  ThruFlow
//
//

import SwiftData
import SwiftUI

struct AreaListView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.calendar) private var calendar
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.modelContext) private var modelContext
    @AppStorage("directionKanbanColumnOrder") private var areaGroupOrderRaw = AreaGroupOrder.encode(AreaGroupOrder.defaultValue)

    var isVisible = true

    @State private var data: MacAreaListData?
    @State private var startsDataSource = false
    @State private var loadFailed = false
    @State private var reportReveal = 0
    @State private var hasNormalizedSortIndexes = false
    @State private var isShowingAddSheet = false
    @State private var editingAreaID: UUID?
    @State private var selectedProject: Project?
    @State private var showingArchived = false
    @State private var lifecycleError: String?
    @State private var draggedAreaID: UUID?
    @State private var dropTargetID: UUID?
    @State private var draggedGroupType: AreaType?
    @State private var dropTargetGroupType: AreaType?

    private var areas: [Area] { data?.areas ?? [] }

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

    private var editingArea: Area? {
        guard let editingAreaID else { return nil }
        return areas.first { $0.id == editingAreaID }
    }

    var body: some View {
        Group {
            if let data {
                AreaBoard(
                    areaGroups: areaGroups,
                    visibleAreas: visibleAreas,
                    projectsByArea: data.projectsByArea,
                    draggedAreaID: $draggedAreaID,
                    dropTargetID: $dropTargetID,
                    draggedGroupType: $draggedGroupType,
                    dropTargetGroupType: $dropTargetGroupType,
                    moveArea: moveArea,
                    moveAreaGroup: moveAreaGroup,
                    onEdit: { editingAreaID = $0.id },
                    onSelectProject: { selectedProject = $0 },
                    onSetArchived: updateArchiveState
                )
                    .transition(reduceMotion ? .identity : .opacity)
            } else if loadFailed {
                ContentUnavailableView(
                    String(localized: "データを読み込めませんでした。"),
                    systemImage: "exclamationmark.circle"
                )
            } else {
                FeatureLoadingIndicator()
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: reportReveal)
        .productContentFade(on: showingArchived)
        .toolbar {
            if isVisible {
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
        }
        .background {
            if isVisible && startsDataSource {
                MacAreaListDataSource { result in
                    switch result {
                    case .success(let newData):
                        let wasUncached = data == nil
                        data = newData
                        loadFailed = false
                        if wasUncached {
                            reportReveal &+= 1
                        }
                    case .failure(let error):
                        loadFailed = true
                        PersistenceIssueCenter.shared.log(error, operation: .dataLoad)
                    }
                }
            }
        }
        .task(id: isVisible) {
            guard isVisible else {
                startsDataSource = false
                return
            }
            await Task.yield()
            guard !Task.isCancelled else { return }
            startsDataSource = true
        }
        .task(id: isVisible && data != nil) {
            guard isVisible, data != nil, !hasNormalizedSortIndexes else { return }
            await Task.yield()
            guard !Task.isCancelled else { return }
            normalizeSortIndexesIfNeeded()
            hasNormalizedSortIndexes = true
        }
        .alert(String(localized: "記録を保存できませんでした。"), isPresented: Binding(
            get: { lifecycleError != nil }, set: { if !$0 { lifecycleError = nil } }
        )) {
            Button(String(localized: "閉じる"), role: .cancel) { lifecycleError = nil }
        }
        .sheet(item: $selectedProject) { project in
            ProjectDetailView(project: project) { todo, project in
                TodoFormView(
                    mode: todo.map(TodoFormView.Mode.edit) ?? .create,
                    fixedArea: todo == nil ? project.area : nil,
                    project: project
                )
            }
        }
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

    private func updateArchiveState(_ area: Area, restore: Bool) {
        let service = AreaLifecycleService(calendar: calendar, dayBoundary: dayBoundary)
        do {
            if restore { try service.restore(area, modelContext: modelContext) }
            else { try service.archive(area, modelContext: modelContext) }
        } catch {
            lifecycleError = String(localized: "記録を保存できませんでした。")
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

#Preview {
    AreaListView()
        .modelContainer(for: [Area.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self], inMemory: true)
}
