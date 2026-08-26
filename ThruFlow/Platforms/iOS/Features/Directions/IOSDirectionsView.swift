import SwiftData
import SwiftUI

struct IOSDirectionsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("directionKanbanColumnOrder") private var groupOrderRaw = DirectionGroupOrder.encode(DirectionGroupOrder.defaultValue)

    @Query(sort: \Direction.sortIndex) private var directions: [Direction]

    @State private var selectedType: DirectionType
    @State private var editorMode: IOSDirectionEditorMode?
    @State private var showingArchived = false
    @State private var isEditingOrder = false
    @State private var showsGroupOrder = false

    init() {
        let first = DirectionGroupOrder.defaultValue.first ?? .habit
        _selectedType = State(initialValue: first)
    }

    private var groupOrder: [DirectionType] {
        DirectionGroupOrder.decode(groupOrderRaw)
    }

    private var visibleDirections: [Direction] {
        directions
            .filter { !DefaultDirections.isTaskInbox($0) }
            .filter { showingArchived ? $0.isArchived : !$0.isArchived }
            .filter { $0.type == selectedType }
            .sorted(by: directionSort)
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
                    ForEach(visibleDirections) { direction in
                        Button {
                            editorMode = .edit(direction)
                        } label: {
                            directionRow(direction)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            if !direction.isArchived {
                                Button(role: .destructive) {
                                    direction.archive()
                                    _ = modelContext.saveReporting(.areaUpdate)
                                } label: {
                                    Label(String(localized: "アーカイブする"), systemImage: "archivebox")
                                }
                            }
                        }
                    }
                    .onMove(perform: moveDirections)
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
                if visibleDirections.isEmpty {
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
                IOSDirectionEditorView(mode: mode)
            }
        }
        .sheet(isPresented: $showsGroupOrder) {
            NavigationStack {
                IOSDirectionGroupOrderView(orderRawValue: $groupOrderRaw)
            }
            .presentationDetents([.medium])
        }
        .onAppear {
            if !groupOrder.contains(selectedType) {
                selectedType = groupOrder.first ?? .habit
            }
        }
    }

    private func directionRow(_ direction: Direction) -> some View {
        HStack(spacing: 12) {
            Text(direction.symbolName)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(Color(hex: direction.colorHex).opacity(0.16), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(direction.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(direction.hasGoal ? goalText(direction) : direction.type.description)
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

    private func moveDirections(from offsets: IndexSet, to destination: Int) {
        var reordered = visibleDirections
        reordered.move(fromOffsets: offsets, toOffset: destination)

        let remaining = directions
            .filter { !$0.isArchived && !DefaultDirections.isTaskInbox($0) && $0.type != selectedType }
            .sorted(by: directionSort)
        let ordered = groupOrder.flatMap { type -> [Direction] in
            type == selectedType ? reordered : remaining.filter { $0.type == type }
        }
        for (index, direction) in ordered.enumerated() {
            direction.setSortIndex(index)
        }
        _ = modelContext.saveReporting(.areaUpdate)
    }

    private func directionSort(_ lhs: Direction, _ rhs: Direction) -> Bool {
        if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }

    private func goalText(_ direction: Direction) -> String {
        let target = direction.goalTarget ?? 1
        let schedule = direction.goalSchedule?.displayName ?? ""

        switch direction.goalUnit {
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

private struct IOSDirectionGroupOrderView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var orderRawValue: String

    @State private var order: [DirectionType]

    init(orderRawValue: Binding<String>) {
        _orderRawValue = orderRawValue
        _order = State(initialValue: DirectionGroupOrder.decode(orderRawValue.wrappedValue))
    }

    var body: some View {
        List {
            ForEach(order) { type in
                Label(type.displayName, systemImage: type.systemImage)
            }
            .onMove { offsets, destination in
                order.move(fromOffsets: offsets, toOffset: destination)
                orderRawValue = DirectionGroupOrder.encode(order)
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

private extension DirectionType {
    var systemImage: String {
        switch self {
        case .neutral: "checklist"
        case .habit: "repeat"
        case .nice: "sparkles"
        }
    }
}

enum IOSDirectionEditorMode: Identifiable {
    case create(initialName: String? = nil)
    case edit(Direction)

    var id: String {
        switch self {
        case .create: "create"
        case .edit(let direction): direction.id.uuidString
        }
    }
}
