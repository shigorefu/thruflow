import SwiftData
import SwiftUI

struct IOSDirectionsView: View {
    @Query(sort: \Direction.sortIndex) private var directions: [Direction]
    @State private var editorMode: IOSDirectionEditorMode?

    var body: some View {
        List {
            ForEach(DirectionType.allCases) { type in
                let values = activeDirections.filter { $0.type == type }
                if !values.isEmpty {
                    Section(type.displayName) {
                        ForEach(values) { direction in
                            Button {
                                editorMode = .edit(direction)
                            } label: {
                                directionRow(direction)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .navigationTitle(String(localized: "方向"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editorMode = .create
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
    }

    private var activeDirections: [Direction] {
        directions.filter { !$0.isArchived && !DefaultDirections.isTaskInbox($0) }
    }

    private func directionRow(_ direction: Direction) -> some View {
        HStack(spacing: 12) {
            Text(direction.symbolName)
                .font(.title2)
                .frame(width: 42, height: 42)
                .background(Color(hex: direction.colorHex).opacity(0.16), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(direction.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text(direction.hasGoal ? goalText(direction) : direction.type.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }

    private func goalText(_ direction: Direction) -> String {
        let target = direction.goalTarget ?? 1
        let unit = direction.goalUnit?.displayName ?? ""
        let schedule = direction.goalSchedule?.displayName ?? ""
        return "\(target) \(unit) · \(schedule)"
    }
}

enum IOSDirectionEditorMode: Identifiable {
    case create
    case edit(Direction)

    var id: String {
        switch self {
        case .create: "create"
        case .edit(let direction): direction.id.uuidString
        }
    }
}
