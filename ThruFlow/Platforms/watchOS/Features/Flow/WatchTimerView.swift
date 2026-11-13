#if os(watchOS)
import Foundation
import SwiftData
import SwiftUI

struct WatchTimerView: View {
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    @Query(sort: \Area.sortIndex) private var areas: [Area]
    @Query private var todos: [Todo]

    @State private var showsMemo = false
    @State private var presentedTaskSwitchID: UUID?
    @State private var isContextPickerVisible = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            GeometryReader { proxy in
                let isCompact = proxy.size.width < 180
                let ringSize = isCompact
                    ? min(66, proxy.size.width * 0.41)
                    : min(proxy.size.width * 0.44, max(76, proxy.size.height - 112))

                VStack(spacing: 4) {
                    contextPicker
                    modePicker(isCompact: isCompact)

                    HStack(spacing: isCompact ? 3 : 6) {
                        WatchTimerRing(now: timeline.date, size: ringSize, tint: primaryTint)
                        WatchTimerControls(
                            isCompact: isCompact,
                            selectedArea: selectedArea,
                            selectedTodo: selectedTodo,
                            primaryTint: primaryTint,
                            showsMemo: $showsMemo
                        )
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 4)
            }
        }
        .sheet(isPresented: $showsMemo, onDismiss: { presentedTaskSwitchID = nil }) {
            WatchFlowMemoView(todo: activeFlowStore.memoTodo, taskSwitchID: presentedTaskSwitchID) {
                showsMemo = false
            }
            .interactiveDismissDisabled(presentedTaskSwitchID != nil)
        }
        .onChange(of: activeFlowStore.pendingTaskSwitch?.id) { _, _ in
            presentTaskSwitchMemoIfNeeded()
        }
    }

    private var contextPicker: some View {
        NavigationLink {
            WatchFlowContextPicker()
                .onAppear { isContextPickerVisible = true }
                .onDisappear {
                    isContextPickerVisible = false
                    presentTaskSwitchMemoIfNeeded()
                }
        } label: {
            HStack(spacing: 6) {
                Text(selectedArea?.symbolName ?? "🎯")
                VStack(alignment: .leading, spacing: 0) {
                    Text(selectedContextTitle)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(selectedArea == nil ? String(localized: "分野") : TodoDisplay.flowContextName(for: selectedTodo, area: selectedArea))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 7)
            .frame(height: 32)
            .background(tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(tint.opacity(0.2))
            }
        }
        .buttonStyle(.plain)
    }

    private func presentTaskSwitchMemoIfNeeded() {
        guard !isContextPickerVisible else { return }
        if showsMemo, let requestID = presentedTaskSwitchID {
            if activeFlowStore.pendingTaskSwitch?.id != requestID { showsMemo = false }
            return
        }
        guard !showsMemo, let requestID = activeFlowStore.pendingTaskSwitch?.id else { return }
        presentedTaskSwitchID = requestID
        showsMemo = true
    }

    private func modePicker(isCompact: Bool) -> some View {
        NavigationLink {
            WatchFlowModePicker()
        } label: {
            HStack {
                Text(activeFlowStore.selectedMode.displayName)
                Spacer()
                if !isCompact {
                    Text(activeFlowStore.selectedMode.compactDurationText)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 7)
            .frame(height: 26)
            .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var activeAreas: [Area] {
        areas.filter { $0.archivedAt == nil }
    }

    private var todayTodos: [Todo] {
        FlowDashboardTodoSorter().sorted(
            todos.filter {
                TodayTodoFilter(
                    calendar: calendar,
                    dayBoundary: dayBoundary
                ).includes($0)
            }
        )
    }

    private var selectedArea: Area? {
        activeAreas.first { $0.id == activeFlowStore.selectedAreaID }
    }

    private var selectedTodo: Todo? {
        todayTodos.first { $0.id == activeFlowStore.selectedTodoID }
    }

    private var selectedContextTitle: String {
        if let selectedTodo {
            return TodoDisplay.flowTitle(for: selectedTodo)
        }
        return selectedArea?.name ?? String(localized: "タスクを選択")
    }

    private var tint: Color {
        activeFlowStore.isBreakPhase
            ? .secondary
            : Color(hex: selectedArea?.colorHex ?? "#0A84FF")
    }

    private var primaryTint: Color {
        switch FlowTimerPrimaryTintRole(
            phase: activeFlowStore.phase,
            isFocusOvertime: false
        ) {
        case .area:
            Color(hex: selectedArea?.colorHex ?? "#0A84FF")
        case .paused, .breakTime:
            .secondary
        }
    }
}
#endif
