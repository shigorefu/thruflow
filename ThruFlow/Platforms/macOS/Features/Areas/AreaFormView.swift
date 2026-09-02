//
//  AreaFormView.swift
//  ThruFlow
//
//

import SwiftData
import SwiftUI

struct AreaFormView: View {
    enum Mode {
        case create
        case edit(Area)

        var title: String {
            switch self {
            case .create:
                String(localized: "新しい方向")
            case .edit:
                String(localized: "方向を編集")
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.calendar) private var calendar
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.modelContext) private var modelContext

    let mode: Mode
    let onSaved: ((Area) -> Void)?

    @State private var draft: AreaDraft
    @State private var validationErrors: [AreaValidationError] = []
    @State private var saveErrorMessage: String?
    @State private var isShowingEmojiPicker = false
    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingHabitPauseDateSheet = false
    @State private var habitPauseEndDate = Date.now

    private let validator = AreaValidator()
    private let typeOptions: [AreaType] = [.neutral, .habit, .nice]

    init(
        mode: Mode,
        initialName: String? = nil,
        initialDraft: AreaDraft? = nil,
        onSaved: ((Area) -> Void)? = nil
    ) {
        self.mode = mode
        self.onSaved = onSaved

        switch mode {
        case .create:
            if let initialDraft {
                _draft = State(initialValue: initialDraft)
            } else {
                var draft = AreaDraft()
                draft.name = initialName ?? ""
                _draft = State(initialValue: draft)
            }
        case .edit(let area):
            _draft = State(initialValue: AreaDraft(area: area))
        }
        _saveErrorMessage = State(initialValue: nil)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerCard
                    typeCard

                    if draft.type == .habit {
                        goalCard

                        if case .edit(let area) = mode {
                            habitPauseCard(area)
                        }
                    }

                    colorCard
                    validationCard
                    deleteCard
                }
                .padding(24)
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(.background)
            .navigationTitle(mode.title)
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "キャンセル")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "保存"), action: save)
                        .accessibilityIdentifier("area.editor.save")
                }
            }
        }
        .onAppear {
            normalizeGoalState(for: draft.type)
        }
        .onChange(of: draft.type) { _, newType in
            normalizeGoalState(for: newType)
        }
        .onChange(of: draft.goalSchedule) { _, _ in
            normalizeGoalState(for: draft.type)
        }
#if os(iOS)
        .sheet(isPresented: $isShowingEmojiPicker) {
            EmojiPickerView(selection: $draft.symbolName)
        }
#else
        .popover(isPresented: $isShowingEmojiPicker, arrowEdge: .bottom) {
            EmojiPickerView(selection: $draft.symbolName)
                .frame(width: 560, height: 680)
        }
#endif
        .confirmationDialog(String(localized: "この方向を削除しますか？"), isPresented: $isShowingDeleteConfirmation) {
            Button(String(localized: "削除"), role: .destructive, action: deleteArea)
            Button(String(localized: "キャンセル"), role: .cancel) {}
        } message: {
            Text(String(localized: "履歴と関連タスクを保つため、方向はアーカイブされます。"))
        }
    }

    private var headerCard: some View {
        AreaSectionCard {
            HStack(alignment: .firstTextBaseline, spacing: 18) {
                Button {
                    isShowingEmojiPicker = true
                } label: {
                    Text(draft.normalizedSymbolName)
                        .font(.system(size: 48))
                        .minimumScaleFactor(0.7)
                        .frame(width: 76, height: 76)
                        .background(Color.secondary.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "絵文字を選択"))
                .accessibilityValue(draft.normalizedSymbolName)

                TextField(String(localized: "名前"), text: $draft.name)
                    .font(.title3.weight(.semibold))
                    .textFieldStyle(.plain)
                    .accessibilityLabel(String(localized: "方向名"))
                    .padding(.bottom, 18)
            }
        }
    }

    private var typeCard: some View {
        AreaSectionCard(title: String(localized: "種類")) {
            Picker(String(localized: "種類"), selection: $draft.type) {
                ForEach(typeOptions) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel(String(localized: "種類"))

            Text(draft.type.description)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var goalCard: some View {
        AreaSectionCard(title: String(localized: "目標")) {
            HStack(spacing: 10) {
                TextField("1", value: goalTargetBinding, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 82)
                    .accessibilityLabel(String(localized: "目標値"))

                Picker(String(localized: "単位"), selection: goalUnitBinding) {
                    ForEach(goalUnitOptions) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 180)
                .accessibilityLabel(String(localized: "単位"))

                Spacer(minLength: 0)
            }

            Picker(String(localized: "頻度"), selection: goalScheduleBinding) {
                ForEach(GoalScheduleKind.allCases) { schedule in
                    Text(schedule.displayName).tag(schedule)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel(String(localized: "頻度"))

            goalScheduleDetails
        }
    }

    private var colorCard: some View {
        AreaSectionCard(title: String(localized: "カラー")) {
            LazyVGrid(columns: colorColumns, alignment: .leading, spacing: 10) {
                ForEach(colorOptions, id: \.hex) { option in
                    Button {
                        draft.colorHex = option.hex
                    } label: {
                        Circle()
                            .fill(Color(hex: option.hex))
                            .frame(width: 30, height: 30)
                            .overlay {
                                if draft.colorHex == option.hex {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(width: 42, height: 38)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.name)
                    .accessibilityAddTraits(draft.colorHex == option.hex ? [.isSelected] : [])
                }
            }
        }
    }

    private func habitPauseCard(_ area: Area) -> some View {
        let period = activePausePeriod(for: area)

        return AreaSectionCard(title: String(localized: "習慣の状態")) {
            HStack(spacing: 12) {
                Image(systemName: period == nil ? "checkmark.circle.fill" : "pause.circle.fill")
                    .font(.title2)
                    .foregroundStyle(period == nil ? Color.green : Color.orange)

                VStack(alignment: .leading, spacing: 3) {
                    Text(period == nil ? String(localized: "有効") : String(localized: "一時停止中"))
                        .font(.body.weight(.semibold))

                    if let period {
                        Text(pauseDescription(for: period))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if period == nil {
                    Menu {
                        Button(String(localized: "今日は休む")) {
                            pauseToday(area)
                        }

                        Button(String(localized: "期間を指定…")) {
                            habitPauseEndDate = logicalToday
                            isShowingHabitPauseDateSheet = true
                        }

                        Divider()

                        Button(String(localized: "再開するまで一時停止")) {
                            pauseIndefinitely(area)
                        }
                    } label: {
                        Label(String(localized: "一時停止"), systemImage: "pause.circle")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .popover(isPresented: $isShowingHabitPauseDateSheet, arrowEdge: .bottom) {
                        habitPauseDatePopover
                    }
                } else {
                    Button(String(localized: "再開")) {
                        resume(area)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Text(String(localized: "一時停止中は予定タスクと達成率の対象から外れます。Flowの記録は残ります。"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var habitPauseDatePopover: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Label(String(localized: "期間を指定"), systemImage: "calendar")
                    .font(.headline)

                Text(String(localized: "終了日"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Divider()

            DatePicker(
                String(localized: "終了日"),
                selection: $habitPauseEndDate,
                in: logicalToday...,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .frame(width: 286)
            .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 8) {
                Spacer(minLength: 0)

                Button(String(localized: "キャンセル")) {
                    isShowingHabitPauseDateSheet = false
                }

                Button(String(localized: "一時停止")) {
                    guard case .edit(let area) = mode else { return }
                    pause(area, through: habitPauseEndDate)
                    isShowingHabitPauseDateSheet = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 318)
    }

    @ViewBuilder
    private var validationCard: some View {
        if !validationErrors.isEmpty || saveErrorMessage != nil {
            AreaSectionCard {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(validationErrors, id: \.self) { error in
                        Label(error.localizedDescription, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }

                    if let saveErrorMessage {
                        Label(saveErrorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var deleteCard: some View {
        if case .edit = mode {
            AreaSectionCard {
                Button(role: .destructive) {
                    isShowingDeleteConfirmation = true
                } label: {
                    Label(String(localized: "方向を削除"), systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
                .accessibilityHint(String(localized: "この方向を削除します"))
            }
        }
    }

    private var goalTargetBinding: Binding<Int> {
        Binding(
            get: { draft.goalTarget ?? 1 },
            set: { draft.goalTarget = $0 }
        )
    }

    private var goalUnitBinding: Binding<GoalUnit> {
        Binding(
            get: { draft.goalUnit ?? .occurrences },
            set: { draft.goalUnit = $0 }
        )
    }

    private var goalScheduleBinding: Binding<GoalScheduleKind> {
        Binding(
            get: { draft.goalSchedule ?? .everyDay },
            set: { draft.goalSchedule = $0 }
        )
    }

    private var weeklyTargetCountBinding: Binding<Int> {
        Binding(
            get: { draft.weeklyTargetCount ?? 1 },
            set: { draft.weeklyTargetCount = $0 }
        )
    }

    @ViewBuilder
    private var goalScheduleDetails: some View {
        switch draft.goalSchedule ?? .everyDay {
        case .everyDay:
            Text(String(localized: "毎日この目標を達成します。"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .weeklyCount:
            WeeklyFrequencySlider(value: weeklyTargetCountBinding)
                .frame(maxWidth: 260)
                .padding(.horizontal, 8)

            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "任意: 曜日も選べます"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                WeekdaySelectionView(selection: $draft.weekdayMask)
            }
        case .weekdays:
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "取り組む曜日"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                WeekdaySelectionView(selection: $draft.weekdayMask)
            }
        }
    }

    private func save() {
        saveErrorMessage = nil
        normalizeGoalState(for: draft.type)
        validationErrors = validator.validate(draft)
        guard validationErrors.isEmpty else { return }

        let requiresGoal = draft.type == .habit
        let goalSchedule = requiresGoal ? draft.goalSchedule : nil
        let goalTarget = requiresGoal ? draft.goalTarget : nil
        let goalPeriod = goalSchedule?.goalPeriod
        let goalUnit = requiresGoal ? draft.goalUnit : nil
        let weeklyTargetCount = requiresGoal && goalSchedule == .weeklyCount ? draft.weeklyTargetCount : nil
        let weekdayMask = requiresGoal && goalSchedule != .everyDay ? draft.weekdayMask : nil

        do {
            let savedArea: Area
            switch mode {
            case .create:
                let area = Area(
                    name: draft.trimmedName,
                    type: draft.type,
                    symbolName: draft.normalizedSymbolName,
                    colorHex: draft.colorHex,
                    goalTarget: goalTarget,
                    goalPeriod: goalPeriod,
                    goalUnit: goalUnit,
                    goalSchedule: goalSchedule,
                    weeklyTargetCount: weeklyTargetCount,
                    weekdayMask: weekdayMask
                )
                modelContext.insert(area)
                savedArea = area
            case .edit(let area):
                let wasHabit = area.type == .habit
                let todos = wasHabit && draft.type == .habit
                    ? try modelContext.fetch(FetchDescriptor<Todo>())
                    : []
                area.update(
                    name: draft.trimmedName,
                    type: draft.type,
                    symbolName: draft.normalizedSymbolName,
                    colorHex: draft.colorHex,
                    goalTarget: goalTarget,
                    goalPeriod: goalPeriod,
                    goalUnit: goalUnit,
                    goalSchedule: goalSchedule,
                    weeklyTargetCount: weeklyTargetCount,
                    weekdayMask: weekdayMask
                )
                if wasHabit, area.type == .habit {
                    reconcileFutureHabitTodos(for: area, todos: todos)
                }
                savedArea = area
            }

            try modelContext.save()
            onSaved?(savedArea)
            dismiss()
        } catch {
            modelContext.rollback()
            saveErrorMessage = String(localized: "記録を保存できませんでした。")
        }
    }

    private func reconcileFutureHabitTodos(for area: Area, todos: [Todo]) {
        _ = HabitScheduleChangeReconciler(
            calendar: calendar,
            dayBoundary: dayBoundary
        ).reconcile(
            area: area,
            todos: todos,
            modelContext: modelContext
        )
    }

    private func deleteArea() {
        guard case .edit(let area) = mode else { return }

        area.archive()
        dismiss()
    }

    private var logicalToday: Date {
        dayBoundary.day(containing: .now, calendar: calendar)
    }

    private func activePausePeriod(for area: Area) -> HabitPausePeriod? {
        HabitPauseService(calendar: calendar, dayBoundary: dayBoundary)
            .activePeriod(for: area, on: logicalToday)
    }

    private func pauseDescription(for period: HabitPausePeriod) -> String {
        guard let endsBefore = period.endsBefore else {
            return String(localized: "再開するまで休み")
        }

        let finalDay = calendar.date(byAdding: .day, value: -1, to: endsBefore) ?? endsBefore
        if calendar.isDate(finalDay, inSameDayAs: logicalToday) {
            return String(localized: "今日のみ休み")
        }

        let date = finalDay.formatted(date: .abbreviated, time: .omitted)
        return String(localized: "\(date)まで休み")
    }

    private func pauseToday(_ area: Area) {
        withHabitTodos { todos in
            _ = HabitPauseService(calendar: calendar, dayBoundary: dayBoundary)
                .pauseToday(area, todos: todos)
        }
    }

    private func pause(_ area: Area, through date: Date) {
        withHabitTodos { todos in
            _ = HabitPauseService(calendar: calendar, dayBoundary: dayBoundary)
                .pause(area, through: date, todos: todos)
        }
    }

    private func pauseIndefinitely(_ area: Area) {
        withHabitTodos { todos in
            _ = HabitPauseService(calendar: calendar, dayBoundary: dayBoundary)
                .pauseIndefinitely(area, todos: todos)
        }
    }

    private func resume(_ area: Area) {
        let service = HabitPauseService(calendar: calendar, dayBoundary: dayBoundary)
        guard service.resume(area) else { return }

        do {
            let todos = try modelContext.fetch(FetchDescriptor<Todo>())
            _ = try HabitTodoMaterializer(
                calendar: calendar,
                dayBoundary: dayBoundary
            ).materialize(
                areas: [area],
                dates: [logicalToday],
                modelContext: modelContext,
                knownTodos: todos,
                reconcilesDuplicates: false
            )
            _ = modelContext.saveReporting(.areaUpdate)
        } catch {
            modelContext.rollback()
            PersistenceIssueCenter.shared.report(error, operation: .habitMaterialization)
        }
    }

    private func withHabitTodos(_ action: ([Todo]) -> Void) {
        do {
            let todos = try modelContext.fetch(FetchDescriptor<Todo>())
            action(todos)
            _ = modelContext.saveReporting(.areaUpdate)
        } catch {
            PersistenceIssueCenter.shared.report(error, operation: .dataLoad)
        }
    }

    private func normalizeGoalState(for type: AreaType) {
        guard type == .habit else {
            draft.goalEnabled = false
            draft.goalTarget = nil
            draft.goalPeriod = nil
            draft.goalUnit = nil
            draft.goalSchedule = nil
            draft.weeklyTargetCount = nil
            draft.weekdayMask = nil
            return
        }

        draft.goalEnabled = true
        draft.goalTarget = draft.goalTarget ?? 1
        draft.goalUnit = draft.goalUnit ?? .occurrences
        draft.goalSchedule = draft.goalSchedule ?? .everyDay
        draft.goalPeriod = draft.goalSchedule?.goalPeriod

        if draft.goalSchedule == .weeklyCount {
            draft.weeklyTargetCount = draft.weeklyTargetCount ?? 1
        }
    }
}

private struct AreaSectionCard<Content: View>: View {
    var title: String?
    @ViewBuilder let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.headline)
            }

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct WeekdaySelectionView: View {
    @Binding var selection: Int?

    var body: some View {
        HStack(spacing: 6) {
            ForEach(GoalWeekday.allCases) { weekday in
                Button {
                    toggle(weekday)
                } label: {
                    Text(weekday.displayName)
                        .font(.body.weight(isSelected(weekday) ? .semibold : .regular))
                        .frame(width: 34, height: 30)
                        .background(isSelected(weekday) ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(weekday.displayName)
                .accessibilityAddTraits(isSelected(weekday) ? [.isSelected] : [])
            }
        }
    }

    private func isSelected(_ weekday: GoalWeekday) -> Bool {
        ((selection ?? 0) & weekday.rawValue) != 0
    }

    private func toggle(_ weekday: GoalWeekday) {
        var mask = selection ?? 0

        if isSelected(weekday) {
            mask &= ~weekday.rawValue
        } else {
            mask |= weekday.rawValue
        }

        selection = mask == 0 ? nil : mask
    }
}

private let colorColumns = [
    GridItem(.adaptive(minimum: 42), spacing: 8)
]

private let colorOptions: [(name: String, hex: String)] = [
    (String(localized: "ブルー"), "#007AFF"),
    (String(localized: "グリーン"), "#34C759"),
    (String(localized: "ミント"), "#00C7BE"),
    (String(localized: "ティール"), "#30B0C7"),
    (String(localized: "シアン"), "#32ADE6"),
    (String(localized: "インディゴ"), "#5856D6"),
    (String(localized: "パープル"), "#AF52DE"),
    (String(localized: "ピンク"), "#FF2D55"),
    (String(localized: "レッド"), "#FF3B30"),
    (String(localized: "オレンジ"), "#FF9500"),
    (String(localized: "イエロー"), "#FFCC00"),
    (String(localized: "グレー"), "#8E8E93")
]

private let goalUnitOptions: [GoalUnit] = [
    .occurrences,
    .focusBlocks,
    .minutes
]

#Preview(String(localized: "方向を作成")) {
    AreaFormView(mode: .create)
        .modelContainer(for: Area.self, inMemory: true)
}
