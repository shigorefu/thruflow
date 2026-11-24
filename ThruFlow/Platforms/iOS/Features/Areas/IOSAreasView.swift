import SwiftData
import SwiftUI

struct IOSAreasView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("directionKanbanColumnOrder") private var groupOrderRaw = AreaGroupOrder.encode(AreaGroupOrder.defaultValue)

    private let isVisible: Bool

    @State private var observesRecords = false
    @State private var records: IOSAreaRecords?
    @State private var loadFailed = false
    @State private var revealsInitialRows = false
    @State private var selectedType: AreaType
    @State private var editorMode: IOSAreaEditorMode?
    @State private var selectedProject: Project?
    @State private var showingArchived = false
    @State private var isEditingOrder = false
    @State private var showsGroupOrder = false
    @State private var saveErrorMessage: String?

    init(isVisible: Bool = true) {
        self.isVisible = isVisible
        let first = AreaGroupOrder.defaultValue.first ?? .habit
        _selectedType = State(initialValue: first)
    }

    private var groupOrder: [AreaType] {
        AreaGroupOrder.decode(groupOrderRaw)
    }

    private var visibleAreas: [Area] {
        visibleAreas(for: selectedType)
    }

    private func visibleAreas(for type: AreaType) -> [Area] {
        let groups = showingArchived ? records?.archivedGroups : records?.activeGroups
        return groups?[type] ?? []
    }

    private var showsGroupBoard: Bool {
        horizontalSizeClass == .regular && !isEditingOrder
    }

    var body: some View {
        Group {
            if showsGroupBoard {
                IOSAreasBoard(
                    groupOrder: groupOrder,
                    records: records,
                    showingArchived: showingArchived,
                    loadFailed: loadFailed,
                    revealsInitialRows: revealsInitialRows,
                    onEditArea: { editorMode = .edit($0) },
                    onArchiveArea: updateArchiveState,
                    onSelectProject: { selectedProject = $0 }
                )
            } else {
                selectedGroupList
                    .frame(maxWidth: 800)
                    .frame(maxWidth: .infinity)
            }
        }
        .background {
            if isVisible, observesRecords {
                IOSAreasQuery { result in
                    switch result {
                    case .success(let records):
                        if self.records == nil { revealsInitialRows = true }
                        self.records = records
                        loadFailed = false
                    case .failure(let error):
                        loadFailed = true
                        PersistenceIssueCenter.shared.log(error, operation: .dataLoad)
                    }
                }
            }
        }
        .productContentFade(on: showingArchived)
        .iosCenteredNavigationTitle(String(localized: "方向"))
        .alert(String(localized: "記録を保存できませんでした。"), isPresented: Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )) {
            Button(String(localized: "完了"), role: .cancel) { saveErrorMessage = nil }
        } message: {
            Text(saveErrorMessage ?? "")
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Toggle(String(localized: "アーカイブ済み"), isOn: $showingArchived)
                    Button(String(localized: "グループを並び替え"), systemImage: "rectangle.3.group") {
                        showsGroupOrder = true
                    }
                    Button(isEditingOrder ? String(localized: "完了") : String(localized: "並び替え")) {
                        withAnimation { isEditingOrder.toggle() }
                    }
                    .disabled(records == nil)
                } label: {
                    IOSMoreMenuLabel()
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editorMode = .create()
                } label: {
                    Label(String(localized: "方向を作成"), systemImage: "plus")
                }
            }
        }
        .sheet(item: $editorMode) { mode in
            NavigationStack {
                IOSAreaEditorView(mode: mode)
            }
        }
        .sheet(item: $selectedProject) { project in
            ProjectDetailView(project: project) { todo, selectedProject in
                NavigationStack {
                    IOSTaskEditorView(
                        mode: todo.map(IOSTaskEditorMode.edit) ?? .create,
                        areas: records?.areas.filter { !$0.isArchived } ?? [],
                        fixedArea: todo == nil ? selectedProject.area : nil,
                        project: selectedProject
                    )
                }
            }
        }
        .sheet(isPresented: $showsGroupOrder) {
            NavigationStack {
                IOSAreaGroupOrderView(orderRawValue: $groupOrderRaw)
            }
            .presentationDetents([.medium])
        }
        .onAppear {
            if !groupOrder.contains(selectedType) {
                selectedType = groupOrder.first ?? .habit
            }
        }
        .task(id: isVisible) {
            guard isVisible else {
                revealsInitialRows = false
                return
            }
            await Task.yield()
            guard !Task.isCancelled else { return }
            observesRecords = true
        }
        .onChange(of: selectedType) { _, _ in revealsInitialRows = false }
        .onChange(of: showingArchived) { _, _ in revealsInitialRows = false }
        .onChange(of: isEditingOrder) { _, _ in revealsInitialRows = false }
    }

    private var selectedGroupList: some View {
        VStack(spacing: 0) {
            Picker(String(localized: "種類"), selection: $selectedType) {
                ForEach(groupOrder) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            IOSAreaGroupHeader(type: selectedType)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 16)
                .background(.background)

            Divider()

            List {
                Section {
                    if isEditingOrder {
                        ForEach(visibleAreas) { area in
                            IOSAreaRow(
                                area: area,
                                isEditingOrder: isEditingOrder,
                                onEditArea: { editorMode = .edit($0) },
                                onArchiveArea: updateArchiveState
                            )
                        }
                        .onMove(perform: moveAreas)
                    } else {
                        ForEach(Array(visibleAreas.enumerated()), id: \.element.id) { index, area in
                            IOSAreaTreeView(
                                area: area,
                                projects: records?.projectsByArea[area.id] ?? [],
                                onEditArea: { editorMode = .edit($0) },
                                onArchiveArea: updateArchiveState,
                                onSelectProject: { selectedProject = $0 }
                            )
                            .featureRowReveal(index: index, enabled: revealsInitialRows)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .productContentFade(on: selectedType)
            .overlay {
                if records == nil {
                    IOSAreasLoadingContent(loadFailed: loadFailed)
                } else if visibleAreas.isEmpty {
                    ContentUnavailableView(
                        showingArchived ? String(localized: "アーカイブはありません") : String(localized: "方向はありません"),
                        systemImage: showingArchived ? "archivebox" : ProductSymbol.area
                    )
                }
            }
            .environment(\.editMode, .constant(isEditingOrder ? .active : .inactive))
        }
    }

    private func moveAreas(from offsets: IndexSet, to destination: Int) {
        var reordered = visibleAreas
        reordered.move(fromOffsets: offsets, toOffset: destination)

        let ordered = groupOrder.flatMap { type -> [Area] in
            type == selectedType ? reordered : records?.activeGroups[type] ?? []
        }
        for (index, area) in ordered.enumerated() {
            area.setSortIndex(index)
        }
        _ = modelContext.saveReporting(.areaUpdate)
    }

    private func updateArchiveState(_ area: Area, archived: Bool) {
        let service = AreaLifecycleService(calendar: calendar, dayBoundary: dayBoundary)
        do {
            if archived {
                try service.archive(area, modelContext: modelContext)
            } else {
                try service.restore(area, modelContext: modelContext)
            }
        } catch {
            saveErrorMessage = String(localized: "記録を保存できませんでした。")
        }
    }

}

enum IOSAreaEditorMode: Identifiable {
    case create(initialName: String? = nil)
    case edit(Area)

    var id: String {
        switch self {
        case .create: "create"
        case .edit(let area): area.id.uuidString
        }
    }
}
