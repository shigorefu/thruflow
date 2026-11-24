#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers

struct AreaBoard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let areaGroups: [AreaGroup]
    let visibleAreas: [Area]
    let projectsByArea: [UUID?: [Project]]
    @Binding var draggedAreaID: UUID?
    @Binding var dropTargetID: UUID?
    @Binding var draggedGroupType: AreaType?
    @Binding var dropTargetGroupType: AreaType?
    let moveArea: (UUID, UUID) -> Void
    let moveAreaGroup: (AreaType, AreaType) -> Void
    let onEdit: (Area) -> Void
    let onSelectProject: (Project) -> Void
    let onSetArchived: (Area, Bool) -> Void

    var body: some View {
        GeometryReader { viewport in
            let columnWidth = max(220, (viewport.size.width - 32 - 28) / 3)

            ScrollView([.horizontal, .vertical]) {
                Grid(alignment: .topLeading, horizontalSpacing: 14, verticalSpacing: 14) {
                    GridRow(alignment: .top) {
                        ForEach(areaGroups) { group in
                            VStack(alignment: .leading, spacing: 10) {
                                AreaSectionHeader(group: group)
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
                                            object: "area-group:\(group.type.rawValue)" as NSString
                                        )
                                    }

                                VStack(spacing: 8) {
                                    if group.areas.isEmpty {
                                        ContentUnavailableView(
                                            String(localized: "方向はありません"),
                                            systemImage: ProductSymbol.area,
                                            description: Text(String(localized: "この列に該当する方向はまだありません。"))
                                        )
                                        .controlSize(.small)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                    }

                                    ForEach(group.areas) { area in
                                        let areaProjects = projectsByArea[area.id] ?? []
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack(spacing: 6) {
                                                AreaRow(area: area)
                                                    .contentShape(Rectangle())
                                                    .overlay {
                                                        if dropTargetID == area.id {
                                                            RoundedRectangle(cornerRadius: 8)
                                                                .strokeBorder(Color.accentColor, lineWidth: 2)
                                                        }
                                                    }
                                                    .onTapGesture {
                                                        onEdit(area)
                                                    }
                                                    .onDrag {
                                                        draggedAreaID = area.id
                                                        return NSItemProvider(object: area.id.uuidString as NSString)
                                                    }
                                                    .onDrop(
                                                        of: [UTType.text],
                                                        delegate: AreaReorderDropDelegate(
                                                            targetID: area.id,
                                                            draggedAreaID: $draggedAreaID,
                                                            dropTargetID: $dropTargetID,
                                                            move: moveArea
                                                        )
                                                    )
                                                    .contextMenu {
                                                        if area.isArchived {
                                                            Button(String(localized: "分野を復元"), systemImage: "arrow.uturn.backward") {
                                                                onSetArchived(area, true)
                                                            }
                                                        } else {
                                                            Button(String(localized: "アーカイブする"), systemImage: "archivebox", role: .destructive) {
                                                                onSetArchived(area, false)
                                                            }
                                                        }
                                                    }

                                            }
                                            .background {
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(Color(hex: area.colorHex).opacity(area.isArchived ? 0.04 : 0.08))
                                            }

                                            projectRows(for: area, projects: areaProjects)
                                        }
                                        .backgroundPreferenceValue(AreaProjectTreeAnchors.self) { anchors in
                                            treeConnections(for: area, projects: areaProjects, anchors: anchors)
                                        }
                                    }
                                }
                                .padding(.bottom, 8)
                            }
                            .frame(width: columnWidth - 24, alignment: .topLeading)
                            .frame(maxHeight: .infinity, alignment: .topLeading)
                            .padding(12)
                            .background(Color.primary.opacity(0.035))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .onDrop(
                                of: [UTType.text],
                                delegate: AreaGroupReorderDropDelegate(
                                    targetType: group.type,
                                    draggedGroupType: $draggedGroupType,
                                    dropTargetGroupType: $dropTargetGroupType,
                                    move: moveAreaGroup
                                )
                            )
                        }
                    }
                }
                .padding(16)
            }
            .scrollIndicators(.visible)
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.22), value: visibleAreas.map(\.id))
    }

    private func projectRows(for area: Area, projects: [Project]) -> some View {
        let orderedProjects = projects.filter { !$0.isCompleted } + projects.filter(\.isCompleted)
        return ForEach(orderedProjects) { project in
            Button { onSelectProject(project) } label: {
                HStack(spacing: 8) {
                    Text(project.name)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if project.isCompleted {
                        Text(String(localized: "プロジェクト完了済み"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: area.colorHex).opacity(project.isCompleted ? 0.045 : 0.08))
                }
                .contentShape(RoundedRectangle(cornerRadius: 8))
                .anchorPreference(key: AreaProjectTreeAnchors.self, value: .bounds) {
                    [.project(project.id): $0]
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(project.isCompleted ? .secondary : .primary)
            .padding(.leading, 52)
        }
    }

    private func treeConnections(
        for area: Area,
        projects: [Project],
        anchors: [AreaProjectTreeNode: Anchor<CGRect>]
    ) -> some View {
        GeometryReader { geometry in
            Path { path in
                guard let areaAnchor = anchors[.area(area.id)] else { return }
                let parent = geometry[areaAnchor]
                let children = projects.compactMap { project in
                    anchors[.project(project.id)].map { geometry[$0] }
                }
                guard let lastY = children.map(\.midY).max() else { return }
                path.move(to: CGPoint(x: parent.midX, y: parent.maxY))
                path.addLine(to: CGPoint(x: parent.midX, y: lastY))
                for child in children {
                    path.move(to: CGPoint(x: parent.midX, y: child.midY))
                    path.addLine(to: CGPoint(x: child.minX, y: child.midY))
                }
            }
            .stroke(Color(hex: area.colorHex).opacity(0.38), style: StrokeStyle(lineWidth: 1.25, lineCap: .round))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

enum AreaProjectTreeNode: Hashable {
    case area(UUID)
    case project(UUID)
}

struct AreaProjectTreeAnchors: PreferenceKey {
    static let defaultValue: [AreaProjectTreeNode: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [AreaProjectTreeNode: Anchor<CGRect>],
        nextValue: () -> [AreaProjectTreeNode: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
#endif
