import SwiftData
import SwiftUI

struct IOSTaskComposer: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.modelContext) private var modelContext

    let directions: [Direction]

    @State private var title = ""
    @State private var directionID: UUID?
    @State private var measurement = TodoMeasurement.checkbox
    @State private var plannedAmount = 1
    @State private var priority = TodoPriority.medium
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
    @AppStorage("settings.showsTaskQuickInputLegend") private var showsQuickInputLegend = true
    @FocusState private var isFocused: Bool

    private let parser = TaskQuickInputParser()

    var body: some View {
        VStack(spacing: 8) {
            if !autocompleteSuggestions.isEmpty {
                autocompletePanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if showsQuickInputLegend && isFocused && !title.isEmpty {
                quickInputLegend
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            VStack(spacing: 10) {
                TextField(String(localized: "タスクを入力してください"), text: $title, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($isFocused)
                    .submitLabel(.send)
                    .onSubmit(submit)
                    .onChange(of: title) { _, _ in
                        applyRecognizedQuickInput()
                    }

                HStack(spacing: 6) {
                    measurementMenu
                    directionMenu
                    priorityMenu
                    dateMenu
                    Spacer(minLength: 0)

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
                }
                .font(.caption.weight(.medium))

            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color.primary.opacity(0.08))
            }
            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .task {
            directionID = nil
            scheduledDate = calendar.startOfDay(for: .now)
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
                .navigationTitle(String(localized: "日付を選択"))
                .navigationBarTitleDisplayMode(.inline)
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
            String(localized: "方向"),
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
                systemImage: hasExplicitMeasurement ? measurementSymbol : "square.dashed"
            )
        }
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
                hasExplicitDirection ? selectedDirection?.name ?? String(localized: "方向") : String(localized: "方向"),
                systemImage: "scope"
            )
        }
    }

    private var priorityMenu: some View {
        Menu {
            ForEach(TodoPriority.allCases) { value in
                Button(value.displayName) {
                    priority = value
                    hasExplicitPriority = true
                }
            }
        } label: {
            compactLabel(
                hasExplicitPriority ? priority.displayName : String(localized: "優先度"),
                systemImage: "flag"
            )
        }
    }

    private var dateMenu: some View {
        Menu {
            Button(String(localized: "今日")) {
                scheduledDate = calendar.startOfDay(for: .now)
                hasExplicitDate = true
            }
            Button(String(localized: "明日")) {
                scheduledDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now))
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
            compactLabel(hasExplicitDate ? dateTitle : String(localized: "日付"), systemImage: "calendar")
        }
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
                    legendItem("@", String(localized: "方向"))
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
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.primary.opacity(0.09))
        }
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
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.primary.opacity(0.09))
        }
        .shadow(color: .black.opacity(0.10), radius: 14, y: 5)
    }

    private func compactLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .lineLimit(1)
            .foregroundStyle(.secondary)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(Color.primary.opacity(0.05), in: Capsule())
    }

    private var selectedDirection: Direction? {
        directions.first { $0.id == directionID }
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
                        systemImage: "scope"
                    )
                }
        case "!":
            return [
                ("high", String(localized: "高")),
                ("medium", String(localized: "中")),
                ("low", String(localized: "低い")),
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
            anchorDate: .now,
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
        let parserDirections = directions.map { TaskQuickInputDirection(id: $0.id, name: $0.name) }
        let result = parser.parse(
            title,
            directions: parserDirections,
            anchorDate: .now,
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
            isRoomIfPossible: result.isRoomIfPossible ?? false,
            plannedAmount: resolvedMeasurement == .checkbox ? nil : resolvedPlannedAmount,
            scheduledDate: resolvedDate(from: result.date)
        )
        modelContext.insert(todo)
        try? modelContext.save()

        title = ""
        measurement = .checkbox
        plannedAmount = 1
        priority = .medium
        scheduledDate = calendar.startOfDay(for: .now)
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
