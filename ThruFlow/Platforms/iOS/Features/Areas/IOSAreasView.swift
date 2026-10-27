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

    @Query(sort: \Area.sortIndex) private var areas: [Area]
    @Query(sort: \Project.createdAt) private var projects: [Project]

    @State private var selectedType: AreaType
    @State private var editorMode: IOSAreaEditorMode?
    @State private var selectedProject: Project?
    @State private var showingArchived = false
    @State private var isEditingOrder = false
    @State private var showsGroupOrder = false
    @State private var saveErrorMessage: String?

    init() {
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
        areas
            .filter { !DefaultAreas.isTaskInbox($0) }
            .filter { showingArchived ? $0.isArchived : !$0.isArchived }
            .filter { $0.type == type }
            .sorted(by: areaSort)
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
                        areas: areas.filter { !$0.isArchived },
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
                        ForEach(visibleAreas) { area in
                            areaTree(area)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .overlay {
                if visibleAreas.isEmpty {
                    ContentUnavailableView(
                        showingArchived ? String(localized: "アーカイブはありません") : String(localized: "方向はありません"),
                        systemImage: showingArchived ? "archivebox" : ProductSymbol.area
                    )
                }
            }
            .environment(\.editMode, .constant(isEditingOrder ? .active : .inactive))
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
                    ForEach(groupOrder) { type in
                        groupColumn(type)
                    }
                }
                .padding(16)
            }
        }
    }

    private func groupColumn(_ type: AreaType) -> some View {
        let groupAreas = visibleAreas(for: type)
        return VStack(alignment: .leading, spacing: 12) {
            groupHeader(type)
            if groupAreas.isEmpty {
                Text(showingArchived ? String(localized: "アーカイブはありません") : String(localized: "方向はありません"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
            }
            ForEach(groupAreas) { area in
                areaTree(area)
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
            ForEach(projectsForArea(area)) { project in
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

    private func projectsForArea(_ area: Area) -> [Project] {
        let children = projects.filter { $0.area?.id == area.id }
        return children.filter { !$0.isCompleted } + children.filter(\.isCompleted)
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

        let remaining = areas
            .filter { !$0.isArchived && !DefaultAreas.isTaskInbox($0) && $0.type != selectedType }
            .sorted(by: areaSort)
        let ordered = groupOrder.flatMap { type -> [Area] in
            type == selectedType ? reordered : remaining.filter { $0.type == type }
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

    private func areaSort(_ lhs: Area, _ rhs: Area) -> Bool {
        if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
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
