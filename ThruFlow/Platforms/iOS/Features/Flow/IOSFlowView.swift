import SwiftData
import SwiftUI

struct IOSFlowView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    @Query(sort: \Direction.sortIndex) private var directions: [Direction]
    @Query(sort: \Todo.sortIndex) private var todos: [Todo]

    @State private var showsContextPicker = false
    @State private var showsMemo = false

    private var activeDirections: [Direction] {
        directions.filter { !$0.isArchived }
    }

    private var todayTodos: [Todo] {
        todos.filter {
            TodayTodoFilter(calendar: calendar).includes($0) && !$0.isCompleted
        }
    }

    private var selectedTodo: Todo? {
        todos.first { $0.id == activeFlowStore.selectedTodoID }
    }

    private var selectedDirection: Direction? {
        if let direction = selectedTodo?.direction { return direction }
        return directions.first { $0.id == activeFlowStore.selectedDirectionID }
    }

    private var selectedContextTitle: String {
        if let selectedTodo {
            return TodoDisplay.title(for: selectedTodo)
        }
        return selectedDirection?.name ?? String(localized: "タスクを選択")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                contextButton
                modePicker
                timer
                controls
            }
            .frame(maxWidth: 560)
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(backgroundColor.ignoresSafeArea())
        .navigationTitle(String(localized: "Flow"))
        .sheet(isPresented: $showsContextPicker) {
            NavigationStack {
                IOSFlowContextPicker(
                    todos: todayTodos,
                    directions: activeDirections,
                    selectedTodoID: activeFlowStore.selectedTodoID,
                    selectedDirectionID: activeFlowStore.selectedDirectionID
                ) { direction, todo in
                    if activeFlowStore.timerState == nil {
                        activeFlowStore.configure(direction: direction, todo: todo)
                    } else {
                        activeFlowStore.selectContext(
                            direction: direction,
                            todo: todo,
                            modelContext: modelContext
                        )
                    }
                    showsContextPicker = false
                }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showsMemo) {
            IOSFlowMemoView(
                isBreakMemo: activeFlowStore.isAwaitingBreakMemo,
                cancel: cancelMemo,
                submit: submitMemo
            )
            .presentationDetents([.medium])
        }
        .task {
            configureInitialContextIfNeeded()
        }
        .task(id: activeFlowStore.timerState?.phase) {
            guard activeFlowStore.timerState != nil else { return }
            while !Task.isCancelled, activeFlowStore.timerState != nil {
                try? await Task.sleep(for: .seconds(1))
                activeFlowStore.refresh(modelContext: modelContext)
                presentMemoIfNeeded()
            }
        }
        .onChange(of: activeFlowStore.isAwaitingBreakMemo) { _, _ in
            presentMemoIfNeeded()
        }
        .onChange(of: activeFlowStore.phase) { _, _ in
            presentMemoIfNeeded()
        }
    }

    private var contextButton: some View {
        Button {
            showsContextPicker = true
        } label: {
            HStack(spacing: 14) {
                if let todo = selectedTodo {
                    TodoProgressControl(
                        todo: todo,
                        additionalFocusSeconds: activeTodoFocusSeconds
                    ) {
                        if todo.setManuallyCompleted(!todo.isCompleted) {
                            try? modelContext.save()
                        }
                    }
                }

                Text(selectedDirection?.symbolName ?? "🎯")
                    .font(.title)
                    .frame(width: 52, height: 52)
                    .background(tint.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 3) {
                    Text(selectedContextTitle)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    if selectedTodo != nil, let direction = selectedDirection {
                        Text(direction.name)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var modePicker: some View {
        Picker(String(localized: "Flowタイプ"), selection: modeBinding) {
            ForEach([FlowMode.twelveThree, .twentyFiveFive, .fiftyTen]) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .disabled(!activeFlowStore.canChangeMode)
    }

    private var timer: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.14), lineWidth: 15)
            Circle()
                .trim(from: 0, to: activeFlowStore.phaseProgress(now: activeFlowStore.displayDate))
                .stroke(tint, style: StrokeStyle(lineWidth: 15, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.25), value: activeFlowStore.displayDate)

            VStack(spacing: 6) {
                Text(activeFlowStore.phase.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(timerText)
                    .font(.system(size: 48, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(activeFlowStore.selectedMode.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 260, height: 260)
        .padding(.vertical, 8)
    }

    private var controls: some View {
        HStack(spacing: 18) {
            controlButton("trash", role: .destructive) {
                activeFlowStore.destroy(modelContext: modelContext)
            }
            .disabled(activeFlowStore.timerState == nil)

            controlButton("stop.fill") {
                activeFlowStore.stop(modelContext: modelContext)
                presentMemoIfNeeded()
            }
            .disabled(activeFlowStore.timerState == nil)

            controlButton("cup.and.saucer.fill") {
                activeFlowStore.requestBreakMemo(modelContext: modelContext)
                presentMemoIfNeeded()
            }
            .disabled(activeFlowStore.timerState == nil || activeFlowStore.isBreakPhase)

            Button(action: primaryAction) {
                Image(systemName: primarySymbol)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(tint, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(selectedDirection == nil)

            controlButton("forward.end.fill") {
                activeFlowStore.seekForward(modelContext: modelContext)
            }
            .disabled(activeFlowStore.timerState == nil || activeFlowStore.isBreakPhase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: Capsule())
    }

    private func controlButton(
        _ systemName: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Image(systemName: systemName)
                .font(.body.weight(.semibold))
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
    }

    private var modeBinding: Binding<FlowMode> {
        Binding(
            get: { activeFlowStore.selectedMode },
            set: { activeFlowStore.selectMode($0, modelContext: modelContext) }
        )
    }

    private var primarySymbol: String {
        guard let state = activeFlowStore.timerState else { return "play.fill" }
        if state.phase == .paused { return "play.fill" }
        if activeFlowStore.isBreakPhase { return "forward.fill" }
        return "pause.fill"
    }

    private var timerText: String {
        activeFlowStore.timerState == nil
            ? activeFlowStore.selectedMode.shortDurationText
            : activeFlowStore.remainingText(now: activeFlowStore.displayDate)
    }

    private var tint: Color {
        if activeFlowStore.isBreakPhase { return Color.secondary }
        return Color(hex: selectedDirection?.colorHex ?? "#007AFF")
    }

    private var backgroundColor: Color {
        tint.opacity(activeFlowStore.timerState == nil ? 0.04 : 0.08)
    }

    private var activeTodoFocusSeconds: Int {
        guard activeFlowStore.timerState != nil else { return 0 }
        return activeFlowStore.actualFocusSeconds(now: activeFlowStore.displayDate)
    }

    private func primaryAction() {
        if activeFlowStore.isBreakPhase {
            guard let direction = selectedDirection else { return }
            activeFlowStore.startNextFlow(
                direction: direction,
                todo: selectedTodo,
                modelContext: modelContext
            )
            return
        }

        if let state = activeFlowStore.timerState {
            if state.phase == .paused {
                activeFlowStore.resume(modelContext: modelContext)
            } else {
                activeFlowStore.pause(modelContext: modelContext)
            }
            return
        }

        guard let direction = selectedDirection else { return }
        activeFlowStore.start(
            direction: direction,
            todo: selectedTodo,
            modelContext: modelContext
        )
    }

    private func configureInitialContextIfNeeded() {
        guard activeFlowStore.selectedDirectionID == nil else { return }
        if let todo = todayTodos.first, let direction = todo.direction {
            activeFlowStore.configure(direction: direction, todo: todo)
        } else if let direction = activeDirections.first {
            activeFlowStore.configure(direction: direction, todo: nil)
        }
    }

    private func presentMemoIfNeeded() {
        showsMemo = activeFlowStore.isAwaitingBreakMemo || activeFlowStore.phase == .awaitingResult
    }

    private func cancelMemo() {
        if activeFlowStore.isAwaitingBreakMemo {
            activeFlowStore.cancelBreakMemo()
        } else {
            activeFlowStore.cancelResultMemo(modelContext: modelContext)
        }
        showsMemo = false
    }

    private func submitMemo(_ memo: String?) {
        if activeFlowStore.isAwaitingBreakMemo {
            activeFlowStore.completeBreakMemo(memo, modelContext: modelContext)
        } else {
            activeFlowStore.completeResult(memo, modelContext: modelContext)
        }
        showsMemo = false
    }
}
