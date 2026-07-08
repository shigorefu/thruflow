//
//  DirectionListView.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/08.
//

import SwiftData
import SwiftUI

struct DirectionListView: View {
    @Query(sort: \Direction.name, order: .forward) private var directions: [Direction]

    @State private var isShowingAddSheet = false
    @State private var editingDirectionID: UUID?
    @State private var showingArchived = false

    private var visibleDirections: [Direction] {
        directions.filter { showingArchived ? $0.isArchived : !$0.isArchived }
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
            } else {
                Section {
                    ForEach(visibleDirections) { direction in
                        DirectionRow(direction: direction)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingDirectionID = direction.id
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if !direction.isArchived {
                                    Button("アーカイブ", systemImage: "archivebox", role: .destructive) {
                                        direction.archive()
                                    }
                                }
                            }
                    }
                }
            }
        }
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
}

private struct DirectionRow: View {
    let direction: Direction

    var body: some View {
        HStack(spacing: 12) {
            Text(direction.symbolName)
                .font(.title2)
                .frame(width: 32, height: 32)
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

            if direction.isArchived {
                Image(systemName: "archivebox")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("アーカイブ済み")
            }
        }
        .padding(.vertical, 4)
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
}

#Preview {
    DirectionListView()
        .modelContainer(for: [Direction.self, Todo.self, FlowSession.self], inMemory: true)
}
