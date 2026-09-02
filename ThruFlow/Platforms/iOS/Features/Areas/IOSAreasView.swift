import SwiftData
import SwiftUI

struct IOSAreasView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("directionKanbanColumnOrder") private var groupOrderRaw = AreaGroupOrder.encode(AreaGroupOrder.defaultValue)

    @Query(sort: \Area.sortIndex) private var areas: [Area]

    @State private var selectedType: AreaType
    @State private var editorMode: IOSAreaEditorMode?
    @State private var showingArchived = false
    @State private var isEditingOrder = false
    @State private var showsGroupOrder = false

    init() {
        let first = AreaGroupOrder.defaultValue.first ?? .habit
        _selectedType = State(initialValue: first)
    }

    private var groupOrder: [AreaType] {
        AreaGroupOrder.decode(groupOrderRaw)
    }

    private var visibleAreas: [Area] {
        areas
            .filter { !DefaultAreas.isTaskInbox($0) }
            .filter { showingArchived ? $0.isArchived : !$0.isArchived }
            .filter { $0.type == selectedType }
            .sorted(by: areaSort)
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker(String(localized: "種類"), selection: $selectedType) {
                ForEach(groupOrder) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)

            List {
                Section {
                    ForEach(visibleAreas) { area in
                        Button {
                            editorMode = .edit(area)
                        } label: {
                            areaRow(area)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            if !area.isArchived {
                                Button(role: .destructive) {
                                    area.archive()
                                    _ = modelContext.saveReporting(.areaUpdate)
                                } label: {
                                    Label(String(localized: "アーカイブする"), systemImage: "archivebox")
                                }
                            }
                        }
                    }
                    .onMove(perform: moveAreas)
                } header: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(selectedType.displayName)
                        Text(selectedType.description)
                            .font(.caption)
                            .textCase(nil)
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
        .iosCenteredNavigationTitle(String(localized: "方向"))
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

    private func areaRow(_ area: Area) -> some View {
        HStack(spacing: 12) {
            Text(area.symbolName)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(Color(hex: area.colorHex).opacity(0.16), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(area.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(area.hasGoal ? goalText(area) : area.type.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
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

    private func areaSort(_ lhs: Area, _ rhs: Area) -> Bool {
        if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }

    private func goalText(_ area: Area) -> String {
        let target = area.goalTarget ?? 1
        let schedule = area.goalSchedule?.displayName ?? ""

        switch area.goalUnit {
        case .occurrences:
            return String(localized: "目標回数：\(target)回・\(schedule)")
        case .focusBlocks:
            return String(localized: "集中ブロック数：\(target)・\(schedule)")
        case .minutes:
            return String(localized: "目標時間：\(target)分・\(schedule)")
        case .hours:
            return String(localized: "目標時間：\(target)時間・\(schedule)")
        case nil:
            return schedule
        }
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
