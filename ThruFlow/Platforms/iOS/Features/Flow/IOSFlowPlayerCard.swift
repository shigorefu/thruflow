#if os(iOS)
import SwiftUI

struct IOSFlowPlayerCard: View {
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    let isVisible: Bool
    let wallClockRevision: Date
    let selectedTodo: Todo?
    let selectedArea: Area?
    let tint: Color
    let onOpenContextPicker: () -> Void
    let onEditTodo: (Todo) -> Void
    let onToggleTodoCompletion: (Todo) -> Void
    let onSelectMode: (FlowMode) -> Void
    let onTransportAction: (FlowTimerPanelAction) -> Void
    let onAppDayChange: (Date) -> Void

    var body: some View {
        FlowTimerPanelShell(style: .mobile) {
            TimelineView(displaySchedule) { tick in
                let now = tick.date
                FlowTimerPresentation(
                    progress: activeFlowStore.phaseProgress(now: now),
                    tint: timerTint(at: now),
                    eyebrow: activeFlowStore.phase.displayName,
                    timeText: timerText(at: now),
                    footer: activeFlowStore.selectedMode.displayName,
                    slices: activeFlowStore.timerRingSlices(now: now)
                )
                .dial(style: .mobile)
            }
        } context: {
            contextButton
        } mode: {
            modePicker
        } controls: {
            TimelineView(FlowPlayerSchedule.overtime(
                for: isVisible ? activeFlowStore.timerState : nil,
                revision: wallClockRevision
            )) { tick in
                controls(now: tick.date)
            }
        }
        .background {
            if isVisible {
                TimelineView(FlowPlayerSchedule.appDay(dayBoundary, calendar, revision: wallClockRevision)) { tick in
                    Color.clear
                        .task(id: dayBoundary.day(containing: tick.date, calendar: calendar)) {
                            onAppDayChange(tick.date)
                        }
                }
            }
        }
    }

    private var contextButton: some View {
        FlowTimerContextButton(
            style: .mobile,
            presentation: FlowTimerContextPresentation(
                symbol: selectedArea?.symbolName ?? "🎯",
                areaTitle: selectedArea == nil ? String(localized: "分野") : TodoDisplay.flowContextName(for: selectedTodo, area: selectedArea),
                tint: tint,
                isPlaceholder: selectedArea == nil,
                showsProgress: selectedTodo != nil
            ),
            accessibilityLabel: selectedContextTitle,
            action: onOpenContextPicker
        ) {
            Text(selectedContextTitle)
                .highPriorityGesture(
                    TapGesture(count: 2).exclusively(before: TapGesture(count: 1))
                        .onEnded { gesture in
                            switch gesture {
                            case .first:
                                if let selectedTodo { onEditTodo(selectedTodo) }
                            case .second:
                                onOpenContextPicker()
                            }
                        }
                )
                .accessibilityAction(named: String(localized: "タスク名を編集")) {
                    if let selectedTodo { onEditTodo(selectedTodo) }
                }
        } progress: {
            Group {
                if let todo = selectedTodo {
                    TimelineView(taskProgressSchedule(for: todo)) { tick in
                        TodoProgressControl(
                            todo: todo,
                            additionalFocusSeconds: activeTodoFocusSeconds(at: tick.date)
                        ) {
                            onToggleTodoCompletion(todo)
                        }
                    }
                }
            }
        }
    }

    private func controls(now: Date) -> some View {
        FlowTimerTransportControls(
            style: .mobile,
            presentation: FlowTimerTransportPresentation(
                primarySymbol: primarySymbol(at: now),
                primaryLabel: primaryActionTitle(at: now),
                primaryTint: primaryTint(at: now),
                isPrimaryEnabled: selectedArea != nil,
                canSeek: canSeek,
                canDestroy: activeFlowStore.timerState != nil,
                canStop: activeFlowStore.timerState != nil,
                canStartBreak: activeFlowStore.canRequestBreak,
                destroyLabel: activeFlowStore.isBreakPhase
                    ? String(localized: "休憩を削除")
                    : String(localized: "Flowを破壊"),
                visuallyPressedAction: nil
            ),
            animatesPrimarySymbol: true,
            action: onTransportAction
        )
    }

    private var selectedContextTitle: String {
        if let selectedTodo { return TodoDisplay.flowTitle(for: selectedTodo) }
        return selectedArea?.name ?? String(localized: "タスクを選択")
    }

    private var displaySchedule: FlowPlayerSchedule {
        .display(for: isVisible ? activeFlowStore.timerState : nil)
    }

    private func taskProgressSchedule(for todo: Todo) -> FlowPlayerSchedule {
        guard todo.measurement != .checkbox, activeFlowStore.timerState?.actualFocusDurationSeconds == nil
        else { return .seconds(active: false) }
        return displaySchedule
    }

    private var modePicker: some View {
        FlowModeSelector(
            selection: modeBinding,
            isSelectionEnabled: activeFlowStore.canChangeMode,
            helpPresentation: .sheet
        )
    }

    private var modeBinding: Binding<FlowMode> {
        Binding(
            get: { activeFlowStore.selectedMode },
            set: onSelectMode
        )
    }

    private func primarySymbol(at date: Date) -> String {
        guard let state = activeFlowStore.timerState else { return "play.fill" }
        if state.phase == .paused { return "play.fill" }
        if activeFlowStore.isBreakPhase { return "forward.fill" }
        if activeFlowStore.isFocusOvertime(now: date) {
            return "cup.and.saucer.fill"
        }
        return "pause.fill"
    }

    private func primaryActionTitle(at date: Date) -> String {
        guard let state = activeFlowStore.timerState else {
            return String(localized: "Flowを開始")
        }
        if state.phase == .paused {
            return String(localized: "再開")
        }
        if activeFlowStore.isBreakPhase {
            return String(localized: "Flowを開始")
        }
        if activeFlowStore.isFocusOvertime(now: date) {
            return String(localized: "休憩")
        }
        return String(localized: "一時停止")
    }

    private var canSeek: Bool {
        activeFlowStore.timerState?.canAdjustRemainingTime == true
    }

    private func timerText(at date: Date) -> String {
        activeFlowStore.timerState == nil
            ? activeFlowStore.selectedMode.compactDurationText
            : activeFlowStore.remainingText(now: date)
    }

    private func primaryTint(at date: Date) -> Color {
        switch FlowTimerPrimaryTintRole(
            phase: activeFlowStore.phase,
            isFocusOvertime: activeFlowStore.isFocusOvertime(now: date)
        ) {
        case .area:
            Color(hex: selectedArea?.colorHex ?? "#007AFF")
        case .paused, .breakTime:
            .secondary
        }
    }

    private func timerTint(at date: Date) -> Color {
        primaryTint(at: date)
    }

    private func activeTodoFocusSeconds(at date: Date) -> Int {
        guard activeFlowStore.timerState != nil else { return 0 }
        return activeFlowStore.actualFocusSeconds(now: date)
    }
}
#endif
