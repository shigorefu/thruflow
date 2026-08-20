import SwiftData
import SwiftUI

struct IOSTaskComposer: View {
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar
    @Environment(\.modelContext) private var modelContext

    let directions: [Direction]
    let initialDraft: TodoDraft?
    let onClose: (() -> Void)?
    let onCreated: ((Todo) -> Void)?

    @State private var title = ""
    @State private var directionID: UUID?
    @State private var measurement = TodoMeasurement.checkbox
    @State private var plannedAmount = 1
    @State private var priority = TodoPriority.medium
    @State private var isRoomIfPossible = false
    @State private var scheduledDate: Date? = .now
    @State private var datePickerValue = Date.now
    @State private var showsDatePicker = false
    @State private var unresolvedDirection: String?
    @State private var directionDraft: IOSDirectionDraft?
    @State private var pendingCreatedDirectionName: String?
    @State private var hasExplicitMeasurement = false
    @State private var hasExplicitDirection = false
    @State private var hasExplicitPriority = false
    @State private var hasExplicitDate = false
    @State private var saveErrorMessage: String?
    @AppStorage("settings.showsTaskQuickInputLegend") private var showsQuickInputLegend = true
    @FocusState private var isFocused: Bool

    private let parser = TaskQuickInputParser()

    init(
        directions: [Direction],
        initialDraft: TodoDraft? = nil,
        onClose: (() -> Void)? = nil,
        onCreated: ((Todo) -> Void)? = nil
    ) {
        self.directions = directions
        self.initialDraft = initialDraft
        self.onClose = onClose
        self.onCreated = onCreated

        let draft = initialDraft ?? TodoDraft(scheduledDate: .now)
        let initialTitle = ([draft.title] + draft.hashtags.map { "#\($0)" })
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        _title = State(initialValue: initialTitle)
        _directionID = State(initialValue: draft.direction?.id)
        _measurement = State(initialValue: draft.measurement)
        _plannedAmount = State(initialValue: max(1, draft.plannedAmount ?? 1))
        _priority = State(initialValue: draft.priority)
        _isRoomIfPossible = State(initialValue: draft.priority == .low && draft.isRoomIfPossible)
        _scheduledDate = State(initialValue: draft.scheduledDate)
        _datePickerValue = State(initialValue: draft.scheduledDate ?? .now)
        _hasExplicitMeasurement = State(initialValue: initialDraft != nil)
        _hasExplicitDirection = State(initialValue: initialDraft?.direction != nil)
        _hasExplicitPriority = State(initialValue: initialDraft != nil)
        _hasExplicitDate = State(initialValue: initialDraft != nil)
        _saveErrorMessage = State(initialValue: nil)
    }

    var body: some View {
        VStack(spacing: 8) {
            if !autocompleteSuggestions.isEmpty {
                autocompletePanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if showsQuickInputLegend && isFocused && !title.isEmpty {
                quickInputLegend
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let saveErrorMessage {
                Label(saveErrorMessage, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
            }

            VStack(spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    TextField(String(localized: "タスクを入力してください"), text: $title, axis: .vertical)
                        .lineLimit(1...4)
                        .focused($isFocused)
                        .submitLabel(.send)
                        .onSubmit(submit)
                        .onChange(of: title) { _, _ in
                            saveErrorMessage = nil
                            applyRecognizedQuickInput()
                        }

                    if let onClose {
                        Button {
                            isFocused = false
                            onClose()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption.weight(.bold))
                                .frame(width: 28, height: 28)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(String(localized: "閉じる"))
                    }
                }

                HStack(spacing: 6) {
                    ScrollView(.horizontal) {
                        HStack(spacing: 6) {
                            measurementMenu
                            directionMenu
                            priorityMenu
                            dateMenu
                        }
                    }
                    .scrollIndicators(.hidden)

                    Button(action: submit) {
                        Image(systemName: "arrow.up")
                            .font(.body.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(canSubmit ? Color.accentColor : Color.secondary.opacity(0.35), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSubmit)
                    .accessibilityLabel(String(localized: "タスクを追加"))
                    .accessibilityIdentifier("task.composer.submit")
                }
                .font(.caption.weight(.medium))

            }
            .padding(12)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .task {
            if initialDraft == nil {
                directionID = nil
                scheduledDate = currentAppDay
            }
            await Task.yield()
            isFocused = true
        }
        .animation(.snappy(duration: 0.22), value: autocompleteSuggestions.map(\.id))
        .sheet(isPresented: $showsDatePicker) {
            NavigationStack {
                DatePicker(
                    String(localized: "日付"),
                    selection: $datePickerValue,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()
                .iosCenteredNavigationTitle(String(localized: "日付を選択"))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "キャンセル")) { showsDatePicker = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "完了")) {
                            scheduledDate = calendar.startOfDay(for: datePickerValue)
                            hasExplicitDate = true
                            showsDatePicker = false
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $directionDraft, onDismiss: selectCreatedDirectionIfAvailable) { draft in
            NavigationStack {
                IOSDirectionEditorView(mode: .create(initialName: draft.name))
            }
        }
        .alert(
            String(localized: "分野"),
            isPresented: Binding(
                get: { unresolvedDirection != nil },
                set: { if !$0 { unresolvedDirection = nil } }
            )
        ) {
            Button(String(localized: "新規作成")) {
                guard let unresolvedDirection else { return }
                pendingCreatedDirectionName = unresolvedDirection
                directionDraft = IOSDirectionDraft(name: unresolvedDirection)
            }
            Button(String(localized: "その他として追加")) {
                useInboxForUnresolvedDirection()
            }
            Button(String(localized: "キャンセル"), role: .cancel) {}
        } message: {
            if let unresolvedDirection {
                Text(
                    String.localizedStringWithFormat(
                        String(localized: "方向「%@」が見つかりません"),
                        unresolvedDirection
                    )
                )
            }
        }
    }

    private var measurementMenu: some View {
        Menu {
            Button {
                measurement = .checkbox
                hasExplicitMeasurement = true
            } label: {
                Label(TodoMeasurement.checkbox.displayName, systemImage: "checkmark.square")
            }
            Button {
                measurement = .focusBlocks
                hasExplicitMeasurement = true
            } label: {
                Label(TodoMeasurement.focusBlocks.displayName, systemImage: "circle")
            }
            Button {
                measurement = .minutes
                hasExplicitMeasurement = true
            } label: {
                Label(TodoMeasurement.minutes.displayName, systemImage: "timer")
            }

            if measurement != .checkbox {
                Divider()
                Stepper(value: $plannedAmount, in: 1...999) {
                    Text(targetText)
                }
            }
        } label: {
            compactLabel(
                hasExplicitMeasurement ? measurementTitle : String(localized: "種類"),
                systemImage: hasExplicitMeasurement ? measurementSymbol : "square.dashed",
                tint: .accentColor,
                isExplicit: hasExplicitMeasurement
            )
        }
        .buttonStyle(.plain)
        .menuOrder(.fixed)
    }

    private var directionMenu: some View {
        Menu {
            ForEach(directions) { direction in
                Button {
                    directionID = direction.id
                    hasExplicitDirection = true
                } label: {
                    Text("\(direction.symbolName) \(direction.name)")
                }
            }
        } label: {
            compactLabel(
                hasExplicitDirection ? selectedDirection?.name ?? String(localized: "分野") : String(localized: "分野"),
                tint: directionTint,
                isExplicit: hasExplicitDirection
            )
        }
        .buttonStyle(.plain)
        .menuOrder(.fixed)
    }

    private var priorityMenu: some View {
        Menu {
            ForEach([TodoPriority.high, .medium, .low]) { value in
                Button(value.displayName) {
                    priority = value
                    isRoomIfPossible = false
                    hasExplicitPriority = true
                }
            }

            Divider()

            Button(String(localized: "余裕があれば")) {
                priority = .low
                isRoomIfPossible = true
                hasExplicitPriority = true
            }
        } label: {
            compactLabel(
                priorityTitle,
                tint: priorityTint,
                isExplicit: hasExplicitPriority
            )
        }
        .buttonStyle(.plain)
        .menuOrder(.fixed)
    }

    private var dateMenu: some View {
        Menu {
            Button(String(localized: "今日")) {
                scheduledDate = currentAppDay
                hasExplicitDate = true
            }
            Button(String(localized: "明日")) {
                scheduledDate = calendar.date(byAdding: .day, value: 1, to: currentAppDay)
                hasExplicitDate = true
            }
            Button(String(localized: "日付なし")) {
                scheduledDate = nil
                hasExplicitDate = true
            }
            Divider()
            Button(String(localized: "日付を選択"), systemImage: "calendar") {
                datePickerValue = scheduledDate ?? .now
                showsDatePicker = true
            }
        } label: {
            compactLabel(
                hasExplicitDate ? dateTitle : String(localized: "日付"),
                isExplicit: false
            )
        }
        .buttonStyle(.plain)
        .menuOrder(.fixed)
    }

    private var quickInputLegend: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(String(localized: "ショートカットを使えます"), systemImage: "command")
                    .font(.caption.weight(.semibold))
                Spacer(minLength: 0)
                Button {
                    showsQuickInputLegend = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "クイック入力のヒントを非表示"))
            }

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 6) {
                GridRow {
                    legendItem("[ ]", String(localized: "チェック"))
                    legendItem("@", String(localized: "分野"))
                }
                GridRow {
                    legendItem("[1b]", String(localized: "1ブロック"))
                    legendItem("!", String(localized: "優先度"))
                }
                GridRow {
                    legendItem("[25m]", String(localized: "25分"))
                    legendItem("/", String(localized: "日付"))
                }
                GridRow {
                    legendItem("#", String(localized: "タグ"))
                }
            }
        }
        .foregroundStyle(.secondary)
        .padding(11)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func legendItem(_ shortcut: String, _ label: String) -> some View {
        HStack(spacing: 7) {
            Text(verbatim: shortcut)
                .font(.caption.monospaced().weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 38, alignment: .leading)
            Text(label)
                .font(.caption)
                .lineLimit(1)
        }
    }

    private var autocompletePanel: some View {
        VStack(spacing: 0) {
            ForEach(autocompleteSuggestions) { suggestion in
                Button {
                    title = parser.replacingTrailingAutocompleteToken(in: title, with: suggestion.replacement) + " "
                    applyRecognizedQuickInput()
                    isFocused = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: suggestion.systemImage)
                            .foregroundStyle(.tint)
                            .frame(width: 22)
                        Text(suggestion.title)
                            .foregroundStyle(.primary)
                        Spacer(minLength: 0)
                        Text(suggestion.replacement)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 42)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if suggestion.id != autocompleteSuggestions.last?.id {
                    Divider().padding(.leading, 44)
                }
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func compactLabel(
        _ title: String,
        systemImage: String? = nil,
        tint: Color = .secondary,
        isExplicit: Bool = false
    ) -> some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
            }

            Text(title)
        }
            .lineLimit(1)
            .foregroundStyle(isExplicit ? tint : Color.primary.opacity(0.72))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                isExplicit ? tint.opacity(0.16) : Color.gray.opacity(0.16),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
            .contentShape(Capsule())
            .fixedSize(horizontal: true, vertical: false)
    }

    private var selectedDirection: Direction? {
        directions.first { $0.id == directionID }
    }

    private var directionTint: Color {
        guard hasExplicitDirection,
              let selectedDirection,
              !DefaultDirections.isTaskInbox(selectedDirection) else {
            return .secondary
        }
        return Color(hex: selectedDirection.colorHex)
    }

    private var priorityTint: Color {
        guard hasExplicitPriority else { return .secondary }

        switch priority {
        case .high: return Color.red
        case .medium: return Color.secondary
        case .low: return Color.green
        }
    }

    private var priorityTitle: String {
        guard hasExplicitPriority else { return String(localized: "優先度") }
        return isRoomIfPossible ? String(localized: "余裕があれば") : priority.displayName
    }

    private var defaultDirection: Direction? {
        DefaultDirections.existingTaskInbox(in: directions) ?? directions.first
    }

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && defaultDirection != nil
    }

    private var measurementTitle: String {
        measurement == .checkbox ? measurement.displayName : targetText
    }

    private var measurementSymbol: String {
        switch measurement {
        case .checkbox: "checkmark.square"
        case .focusBlocks: "circle"
        case .minutes: "timer"
        }
    }

    private var targetText: String {
        switch measurement {
        case .checkbox: measurement.displayName
        case .focusBlocks: "\(plannedAmount) \(String(localized: "ブロック"))"
        case .minutes: "\(plannedAmount) \(String(localized: "分"))"
        }
    }

    private var dateTitle: String {
        guard let scheduledDate else { return String(localized: "日付なし") }
        if calendar.isDateInToday(scheduledDate) { return String(localized: "今日") }
        if calendar.isDateInTomorrow(scheduledDate) { return String(localized: "明日") }
        return scheduledDate.formatted(.dateTime.month(.abbreviated).day())
    }

    private var autocompleteSuggestions: [IOSQuickInputSuggestion] {
        guard let token = parser.trailingAutocompleteToken(in: title) else { return [] }
        let query = String(token.dropFirst()).lowercased()

        switch token.first {
        case "@":
            return directions
                .filter { !$0.isArchived && (query.isEmpty || $0.name.lowercased().contains(query)) }
                .prefix(6)
                .map {
                    IOSQuickInputSuggestion(
                        id: $0.id.uuidString,
                        title: "\($0.symbolName) \($0.name)",
                        replacement: "@\($0.name)",
                        systemImage: ProductSymbol.area
                    )
                }
        case "!":
            return [
                ("high", String(localized: "高")),
                ("medium", String(localized: "中")),
                ("low", String(localized: "低")),
                ("later", String(localized: "余裕があれば")),
            ]
            .filter { query.isEmpty || $0.0.hasPrefix(query) }
            .map { IOSQuickInputSuggestion(id: "!\($0.0)", title: $0.1, replacement: "!\($0.0)", systemImage: "flag") }
        case "/":
            return [
                ("today", String(localized: "今日")),
                ("tomorrow", String(localized: "明日")),
                ("nodate", String(localized: "日付なし")),
            ]
            .filter { query.isEmpty || $0.0.hasPrefix(query) }
            .map { IOSQuickInputSuggestion(id: "/\($0.0)", title: $0.1, replacement: "/\($0.0)", systemImage: "calendar") }
        case "[":
            return [
                IOSQuickInputSuggestion(id: "check", title: TodoMeasurement.checkbox.displayName, replacement: "[]", systemImage: "checkmark.square"),
                IOSQuickInputSuggestion(id: "block", title: "1 \(String(localized: "ブロック"))", replacement: "[1b]", systemImage: "circle"),
                IOSQuickInputSuggestion(id: "minutes", title: "25 \(String(localized: "分"))", replacement: "[25m]", systemImage: "timer"),
            ]
        default:
            return []
        }
    }

    private func applyRecognizedQuickInput() {
        let result = parser.parse(
            title,
            directions: directions.map { TaskQuickInputDirection(id: $0.id, name: $0.name) },
            anchorDate: currentAppDay,
            calendar: calendar,
            consumeTrailingToken: false
        )

        if let value = result.measurement {
            measurement = value
            plannedAmount = result.plannedAmount ?? 1
            hasExplicitMeasurement = true
        }
        if let id = result.directionID {
            directionID = id
            hasExplicitDirection = true
        }
        if let value = result.priority {
            priority = value
            isRoomIfPossible = result.isRoomIfPossible ?? false
            hasExplicitPriority = true
        }
        if let value = result.date {
            hasExplicitDate = true
            switch value {
            case .scheduled(let date): scheduledDate = calendar.startOfDay(for: date)
            case .noDate: scheduledDate = nil
            }
        }
    }

    private func submit() {
        saveErrorMessage = nil
        let parserDirections = directions.map { TaskQuickInputDirection(id: $0.id, name: $0.name) }
        let result = parser.parse(
            title,
            directions: parserDirections,
            anchorDate: currentAppDay,
            calendar: calendar
        )
        if let unresolved = result.unresolvedDirection {
            unresolvedDirection = unresolved
            return
        }

        let normalizedTitle = result.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty,
              let direction = directions.first(where: { $0.id == result.directionID ?? directionID })
                ?? defaultDirection else { return }

        let resolvedMeasurement = result.measurement ?? measurement
        let resolvedPlannedAmount = result.measurement == nil ? plannedAmount : result.plannedAmount ?? 1
        let todo = Todo(
            title: normalizedTitle,
            hashtags: result.hashtags,
            direction: direction,
            measurement: resolvedMeasurement,
            priority: result.priority ?? priority,
            isRoomIfPossible: result.isRoomIfPossible ?? isRoomIfPossible,
            plannedAmount: resolvedMeasurement == .checkbox ? nil : resolvedPlannedAmount,
            scheduledDate: resolvedDate(from: result.date)
        )
        modelContext.insert(todo)

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            saveErrorMessage = String(localized: "記録を保存できませんでした。")
            return
        }

        onCreated?(todo)

        title = ""
        measurement = .checkbox
        plannedAmount = 1
        priority = .medium
        isRoomIfPossible = false
        scheduledDate = currentAppDay
        directionID = nil
        hasExplicitMeasurement = false
        hasExplicitDirection = false
        hasExplicitPriority = false
        hasExplicitDate = false
        isFocused = true
    }

    private func resolvedDate(from parsedDate: TaskQuickInputDate?) -> Date? {
        if let parsedDate {
            switch parsedDate {
            case .scheduled(let date): return date
            case .noDate: return nil
            }
        }

        return scheduledDate
    }

    private var currentAppDay: Date {
        dayBoundary.day(containing: .now, calendar: calendar)
    }

    private func useInboxForUnresolvedDirection() {
        guard let unresolvedDirection else { return }
        title = removingDirectionToken(unresolvedDirection, from: title)
        directionID = defaultDirection?.id
        hasExplicitDirection = true
        self.unresolvedDirection = nil
        isFocused = true
    }

    private func selectCreatedDirectionIfAvailable() {
        guard let name = pendingCreatedDirectionName,
              let direction = directions.first(where: {
                  $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
              }) else {
            pendingCreatedDirectionName = nil
            return
        }

        title = title.replacingOccurrences(of: "@\(name)", with: "@\(direction.name)")
        directionID = direction.id
        hasExplicitDirection = true
        unresolvedDirection = nil
        pendingCreatedDirectionName = nil
        isFocused = true
    }

    private func removingDirectionToken(_ name: String, from source: String) -> String {
        source
            .replacingOccurrences(of: "@\(name)", with: "")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct IOSQuickInputSuggestion: Identifiable {
    let id: String
    let title: String
    let replacement: String
    let systemImage: String
}

private struct IOSDirectionDraft: Identifiable {
    let id = UUID()
    let name: String
}
