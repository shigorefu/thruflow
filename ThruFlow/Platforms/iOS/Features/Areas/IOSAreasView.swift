import SwiftData
import SwiftUI

struct IOSAreasView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var minimumGroupWidth = 240.0
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
                groupBoard
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

            groupHeader(selectedType)
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
                            areaButton(area)
                        }
                        .onMove(perform: moveAreas)
                    } else {
                        ForEach(Array(visibleAreas.enumerated()), id: \.element.id) { index, area in
                            areaTree(area)
                                .featureRowReveal(index: index, enabled: revealsInitialRows)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .productContentFade(on: selectedType)
            .overlay {
                if records == nil {
                    loadingContent
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

    @ViewBuilder
    private var loadingContent: some View {
        if loadFailed {
            ContentUnavailableView(
                String(localized: "データを読み込めませんでした。"),
                systemImage: "exclamationmark.triangle"
            )
        } else {
            FeatureLoadingIndicator()
        }
    }

    private var groupBoard: some View {
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
            if records == nil { loadingContent }
        }
    }

    private func groupColumn(_ type: AreaType, columnIndex: Int) -> some View {
        let groupAreas = visibleAreas(for: type)
        return LazyVStack(alignment: .leading, spacing: 12) {
            groupHeader(type)
            if records != nil && groupAreas.isEmpty {
                Text(showingArchived ? String(localized: "アーカイブはありません") : String(localized: "方向はありません"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
            }
            ForEach(Array(groupAreas.enumerated()), id: \.element.id) { index, area in
                areaTree(area)
                    .featureRowReveal(index: index + columnIndex, enabled: revealsInitialRows)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
    }

    private func groupHeader(_ type: AreaType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(type.displayName, systemImage: type.systemImage)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            Text(type.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func areaButton(_ area: Area) -> some View {
        Button {
            editorMode = .edit(area)
        } label: {
            areaRow(area)
        }
        .buttonStyle(.plain)
        .contextMenu {
            archiveAction(for: area)
        }
        .padding(12)
        .background(Color(hex: area.colorHex).opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func archiveAction(for area: Area) -> some View {
        if area.isArchived {
            Button {
                updateArchiveState(area, archived: false)
            } label: {
                Label(String(localized: "分野を復元"), systemImage: "arrow.uturn.backward")
            }
        } else {
            Button(role: .destructive) {
                updateArchiveState(area, archived: true)
            } label: {
                Label(String(localized: "アーカイブする"), systemImage: "archivebox")
            }
        }
    }

    private func areaTree(_ area: Area) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            areaButton(area)
            ForEach(records?.projectsByArea[area.id] ?? []) { project in
                projectButton(project)
                    .padding(.leading, 56)
            }
        }
        .backgroundPreferenceValue(IOSAreaTreeBoundsKey.self) { bounds in
            GeometryReader { geometry in
                if let emoji = bounds.emoji {
                    let origin = geometry[emoji]
                    let children = bounds.projects.values.map { geometry[$0] }.sorted { $0.midY < $1.midY }
                    Path { path in
                        if let last = children.last {
                            path.move(to: CGPoint(x: origin.midX, y: origin.maxY))
                            path.addLine(to: CGPoint(x: origin.midX, y: last.midY))
                            for child in children {
                                path.move(to: CGPoint(x: origin.midX, y: child.midY))
                                path.addLine(to: CGPoint(x: child.minX, y: child.midY))
                            }
                        }
                    }
                    .stroke(Color(hex: area.colorHex).opacity(0.45), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func projectButton(_ project: Project) -> some View {
        Button {
            selectedProject = project
        } label: {
            HStack(spacing: 10) {
                Text(project.name)
                    .foregroundStyle(project.isCompleted ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if project.isCompleted {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .frame(minHeight: 44)
            .background(Color(hex: project.area?.colorHex ?? "#8E8E93").opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .anchorPreference(key: IOSAreaTreeBoundsKey.self, value: .bounds) {
            IOSAreaTreeBounds(projects: [project.id: $0])
        }
        .accessibilityValue(project.isCompleted ? String(localized: "プロジェクト完了済み") : "")
    }

    private func areaRow(_ area: Area) -> some View {
        HStack(spacing: 12) {
            Text(area.symbolName)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(Color(hex: area.colorHex).opacity(0.16), in: RoundedRectangle(cornerRadius: 10))
                .anchorPreference(key: IOSAreaTreeBoundsKey.self, value: .bounds) {
                    IOSAreaTreeBounds(emoji: $0)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(area.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 0)
            Image(systemName: isEditingOrder ? "line.3.horizontal" : "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
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

private struct IOSAreaRecords {
    let areas: [Area]
    let activeGroups: [AreaType: [Area]]
    let archivedGroups: [AreaType: [Area]]
    let projectsByArea: [UUID: [Project]]

    init(areas: [Area], projects: [Project]) {
        self.areas = areas
        let sortedAreas = areas.filter { !DefaultAreas.isTaskInbox($0) }.sorted { lhs, rhs in
            if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
        activeGroups = Dictionary(grouping: sortedAreas.filter { !$0.isArchived }, by: \.type)
        archivedGroups = Dictionary(grouping: sortedAreas.filter(\.isArchived), by: \.type)
        let projectEntries = projects.compactMap { project in
            project.area.map { (areaID: $0.id, project: project) }
        }
        projectsByArea = Dictionary(grouping: projectEntries, by: \.areaID).mapValues { entries in
            let children = entries.map(\.project)
            return children.filter { !$0.isCompleted } + children.filter(\.isCompleted)
        }
    }
}

private struct IOSAreasQuery: View {
    @Query(sort: \Area.sortIndex) private var areas: [Area]
    @Query(sort: \Project.createdAt) private var projects: [Project]

    let onUpdate: (Result<IOSAreaRecords, Error>) -> Void

    var body: some View {
        let revision = [
            areas.map { RecordRevision(id: $0.id, updatedAt: $0.updatedAt) },
            projects.map { RecordRevision(id: $0.id, updatedAt: $0.updatedAt) }
        ]
        let error = _areas.fetchError ?? _projects.fetchError
        Color.clear
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .task(id: QueryRevision(records: revision, failed: error != nil)) {
                guard !Task.isCancelled else { return }
                if let error {
                    onUpdate(.failure(error))
                } else {
                    onUpdate(.success(IOSAreaRecords(areas: areas, projects: projects)))
                }
            }
    }

    private struct RecordRevision: Hashable {
        let id: UUID
        let updatedAt: Date
    }

    private struct QueryRevision: Hashable {
        let records: [[RecordRevision]]
        let failed: Bool
    }
}

private struct IOSAreaTreeBounds {
    var emoji: Anchor<CGRect>?
    var projects: [UUID: Anchor<CGRect>] = [:]
}

private struct IOSAreaTreeBoundsKey: PreferenceKey {
    static var defaultValue: IOSAreaTreeBounds { IOSAreaTreeBounds() }

    static func reduce(value: inout IOSAreaTreeBounds, nextValue: () -> IOSAreaTreeBounds) {
        let next = nextValue()
        value.emoji = next.emoji ?? value.emoji
        value.projects.merge(next.projects) { _, latest in latest }
    }
}

private struct IOSAreaGroupOrderView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var orderRawValue: String

    @State private var order: [AreaType]

    init(orderRawValue: Binding<String>) {
        _orderRawValue = orderRawValue
        _order = State(initialValue: AreaGroupOrder.decode(orderRawValue.wrappedValue))
    }

    var body: some View {
        List {
            ForEach(order) { type in
                Label(type.displayName, systemImage: type.systemImage)
            }
            .onMove { offsets, destination in
                order.move(fromOffsets: offsets, toOffset: destination)
                orderRawValue = AreaGroupOrder.encode(order)
            }
        }
        .environment(\.editMode, .constant(.active))
        .iosCenteredNavigationTitle(String(localized: "グループを並び替え"))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "完了")) { dismiss() }
            }
        }
    }
}

private extension AreaType {
    var systemImage: String {
        switch self {
        case .neutral: "checklist"
        case .habit: "repeat"
        case .nice: "sparkles"
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
