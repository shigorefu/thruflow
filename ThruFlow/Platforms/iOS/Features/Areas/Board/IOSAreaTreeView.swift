#if os(iOS)
import SwiftUI

struct IOSAreaTreeView: View {
    let area: Area
    let projects: [Project]
    let onEditArea: (Area) -> Void
    let onArchiveArea: (Area, Bool) -> Void
    let onSelectProject: (Project) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            IOSAreaRow(area: area, isEditingOrder: false, onEditArea: onEditArea, onArchiveArea: onArchiveArea)
            ForEach(projects) { project in
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
            onSelectProject(project)
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
}

struct IOSAreaRow: View {
    let area: Area
    let isEditingOrder: Bool
    let onEditArea: (Area) -> Void
    let onArchiveArea: (Area, Bool) -> Void

    var body: some View {
        Button {
            onEditArea(area)
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
                onArchiveArea(area, false)
            } label: {
                Label(String(localized: "分野を復元"), systemImage: "arrow.uturn.backward")
            }
        } else {
            Button(role: .destructive) {
                onArchiveArea(area, true)
            } label: {
                Label(String(localized: "アーカイブする"), systemImage: "archivebox")
            }
        }
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
#endif
