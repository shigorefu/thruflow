#if os(macOS)
import SwiftData
import SwiftUI

private struct MacComposerSuggestionSource: View {
    @Query(sort: \Todo.updatedAt, order: .reverse) private var suggestions: [Todo]
    @Binding var todos: [Todo]

    var body: some View {
        Color.clear
            .onChange(of: suggestions.map(\.updatedAt), initial: true) { _, _ in
                todos = suggestions
            }
    }
}

/// Compact, chip-based quick-add composer pinned to the bottom of Tasks.
struct MessengerTodoComposer: View {
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar
    @State private var focusedSuggestionTodos: [Todo] = []

    @Binding var title: String
    @Binding var selectedAreaID: UUID?
    @Binding var selectedProject: Project?
    @Binding var volume: QuickTodoVolume
    @Binding var priority: TodoPriority
    @Binding var isRoomIfPossible: Bool
    @Binding var dateOption: QuickTodoDate
    @Binding var timeMinutes: Int?
    @Binding var reminderEnabled: Bool
    @Binding var hashtags: [String]

    let areas: [Area]
    let validationMessage: String?
    var suggestionTodos: [Todo]?
    var allowsSubmission = true
    var allowsDateSelection = true
    var showsOuterBackground = true
    var suggestionsBelow = false
    var allowsQuickInputLegend = true
    var onCancel: (() -> Void)?
    let onSubmit: () -> Bool

    @FocusState private var isFocused: Bool
    @AppStorage("settings.showsTaskQuickInputLegend") private var showsQuickInputLegend = true
    @State private var parserMessage: String?
    @State private var pendingAreaName: String?
    @State private var isApplyingParserResult = false
    @State private var inlineTokens: [TaskComposerInlineToken] = []
    @State private var hasExplicitArea = false
    @State private var hasExplicitPriority = false
    @State private var hasExplicitDate = false
    @State private var showsTimingControls = false
    @State private var selectedAutocompleteSuggestionID: String?

    private let parser = TaskQuickInputParser()

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        composerSurface
        .background {
            if suggestionTodos == nil && isFocused {
                MacComposerSuggestionSource(todos: $focusedSuggestionTodos)
            }
        }
        .animation(.snappy(duration: 0.22), value: hasComposerContent)
        .animation(.snappy(duration: 0.18), value: activeAutocompleteSuggestions.map(\.id))
        .padding(.horizontal, showsOuterBackground ? 12 : 0)
        .padding(.vertical, showsOuterBackground ? 8 : 0)
        .background {
            if showsOuterBackground {
                Rectangle().fill(.bar)
            }
        }
        .background {
            TaskComposerSuggestionPanel(isPresented: !activeAutocompleteSuggestions.isEmpty ||
                (allowsQuickInputLegend && showsQuickInputLegend && isFocused && hasComposerContent), showsBelow: suggestionsBelow) {
                if !activeAutocompleteSuggestions.isEmpty {
                    autocompleteSuggestions(activeAutocompleteSuggestions)
                } else {
                    quickInputLegend.frame(width: 360)
                }
            }
        }
        .taskTimingDefaults(timeMinutes: $timeMinutes, reminderEnabled: $reminderEnabled)
        .onChange(of: volume) { _, newValue in
            updateExistingInlineToken(
                .measurement(newValue.measurement, newValue.plannedAmount)
            )
        }
        .onChange(of: selectedAreaID) { _, newValue in
            if selectedProject?.area?.id != newValue { selectedProject = nil }
            updateExistingInlineToken(newValue.map(TaskComposerInlineToken.area), id: "area")
        }
        .onChange(of: priority) { _, newValue in
            updateExistingInlineToken(.priority(newValue, isRoomIfPossible))
        }
        .onChange(of: isRoomIfPossible) { _, newValue in
            updateExistingInlineToken(.priority(priority, newValue))
        }
        .onChange(of: dateOption) { _, newValue in
            updateExistingInlineToken(.date(newValue))
            clearTimingIfUndated()
        }
        .onChange(of: activeAutocompleteSuggestions.map(\.id)) { _, _ in
            selectedAutocompleteSuggestionID = nil
        }
    }

    private var composerSurface: some View {
        VStack(alignment: .leading, spacing: 10) {
            inputArea

            controlBar
            if let area = areas.first(where: { $0.id == selectedAreaID }) {
                TaskProjectPicker(area: area, selection: $selectedProject)
                    .font(.caption)
            }

            if let message = parserMessage ?? validationMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if let pendingAreaName {
                unresolvedAreaActions(name: pendingAreaName)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background {
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.primary.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(Color.primary.opacity(0.12))
        }
    }

    private var inputArea: some View {
        VStack(alignment: .leading, spacing: 9) {
            if !inlineTokens.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 5) {
                        ForEach(inlineTokens) { token in
                            Button {
                                removeInlineToken(token)
                            } label: {
                                inlineTokenView(token)
                            }
                            .buttonStyle(.plain)
                            .help(String(localized: "トークンを削除"))
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }

            HStack(alignment: .top, spacing: 8) {
                TextField(String(localized: "タスクを入力してください"), text: $title, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .lineLimit(2...5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .focused($isFocused)
                    .onSubmit {
                        if !activateSelectedAutocompleteSuggestion() {
                            submit()
                        }
                    }
                    .onKeyPress(.upArrow) {
                        moveAutocompleteSelection(by: -1) ? .handled : .ignored
                    }
                    .onKeyPress(.downArrow) {
                        moveAutocompleteSelection(by: 1) ? .handled : .ignored
                    }
                    .onChange(of: title) { _, newValue in
                        parseCommittedTokens(in: newValue)
                    }

                if let onCancel {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help(String(localized: "閉じる"))
                    .accessibilityLabel(String(localized: "タスク作成を閉じる"))
                }

                submitButton
            }
        }
        .animation(.snappy(duration: 0.22), value: inlineTokens)
    }

    private var controlBar: some View {
        HStack(spacing: 8) {
            VolumeChip(volume: $volume)

            AreaChip(
                selectedAreaID: $selectedAreaID,
                isExplicit: $hasExplicitArea,
                areas: areas
            )
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(3)

            PriorityChip(
                priority: $priority,
                isRoomIfPossible: $isRoomIfPossible,
                isExplicit: $hasExplicitPriority
            )

            if priority == .low {
                RoomIfPossibleChip(isSelected: $isRoomIfPossible)
            }

            if allowsDateSelection {
                DateChip(dateOption: $dateOption, isExplicit: $hasExplicitDate)
            } else {
                Text(String(localized: "今日"))
                    .chipStyle(tint: .secondary)
                    .accessibilityLabel(String(localized: "日付 今日"))
            }

            timingButton

            ForEach(hashtags, id: \.self) { hashtag in
                Button {
                    hashtags.removeAll { $0.caseInsensitiveCompare(hashtag) == .orderedSame }
                    inlineTokens.removeAll { $0.hashtagMatches(hashtag) }
                } label: {
                    Text(verbatim: "#\(hashtag)")
                        .chipStyle(tint: .accentColor)
                }
                .buttonStyle(.plain)
                .help(String(localized: "タグを削除"))
            }

            Spacer(minLength: 0)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private var timingButton: some View {
        Button {
            showsTimingControls = true
        } label: {
            HStack(spacing: 5) {
                if let timeMinutes {
                    TaskTimeLabel(minutes: timeMinutes, reminderEnabled: reminderEnabled)
                } else {
                    Label(String(localized: "時刻"), systemImage: "clock")
                }
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityIdentifier("task.composer.timing")
        .popover(isPresented: $showsTimingControls) {
            TaskTimingControls(
                scheduledDate: dateOption.resolvedDate(calendar: calendar, dayBoundary: dayBoundary),
                timeMinutes: $timeMinutes,
                reminderEnabled: $reminderEnabled
            )
            .padding(16)
            .frame(width: 300)
        }
    }

    private func clearTimingIfUndated() {
        guard dateOption == .none else { return }
        timeMinutes = nil
        reminderEnabled = false
    }

    private func submit() {
        guard canSubmit else { return }
        let result = parser.parse(
            title,
            areas: parserAreas,
            anchorDate: dayBoundary.day(containing: .now, calendar: calendar),
            calendar: calendar,
            consumeTrailingToken: true
        )
        apply(result)
        // A trailing @ token can change Area before onChange is delivered.
        if selectedProject?.area?.id != selectedAreaID { selectedProject = nil }
        if let unresolved = result.unresolvedArea, !unresolved.isEmpty {
            pendingAreaName = unresolved
            parserMessage = String(localized: "方向「\(unresolved)」が見つかりません")
            isFocused = true
            return
        }
        pendingAreaName = nil
        parserMessage = nil
        if onSubmit() {
            clearInlineTokensAfterSubmission()
        }
        isFocused = true
    }

    private var parserAreas: [TaskQuickInputArea] {
        areas.map { TaskQuickInputArea(id: $0.id, name: $0.name) }
    }

    private var hasComposerContent: Bool {
        !trimmedTitle.isEmpty || !inlineTokens.isEmpty
    }

    private var canSubmit: Bool {
        guard allowsSubmission else { return false }
        return hasComposerContent || hasExplicitArea || hasExplicitPriority || hasExplicitDate
            || volume != .unspecified || !hashtags.isEmpty || selectedProject != nil || timeMinutes != nil
    }

    private var autocompleteToken: String? {
        guard isFocused else { return nil }
        return parser.trailingAutocompleteToken(in: title)
    }

    private var availableSuggestionTodos: [Todo] {
        suggestionTodos?.sorted { $0.updatedAt > $1.updatedAt } ?? focusedSuggestionTodos
    }

    private var activeAutocompleteSuggestions: [TaskComposerAutocompleteSuggestion] {
        guard isFocused else { return [] }
        if let autocompleteToken {
            return autocompleteSuggestionItems(for: autocompleteToken)
        }
        return TaskTitleSuggestionBuilder()
            .suggestions(query: title, todos: availableSuggestionTodos)
            .map { suggestion in
                TaskComposerAutocompleteSuggestion(
                    id: "title:\(suggestion.id)",
                    icon: "clock.arrow.circlepath",
                    title: suggestion.title,
                    action: .title(suggestion.title)
                )
            }
    }

    private var submitButton: some View {
        Button(action: submit) {
            Image(systemName: "arrow.up")
                .font(.system(size: 13, weight: .bold))
                .frame(width: 30, height: 30)
                .background(Color.accentColor, in: Circle())
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .help(String(localized: "タスクを追加"))
        .accessibilityLabel(String(localized: "タスクを追加"))
        .accessibilityIdentifier("task.composer.submit")
        .disabled(!canSubmit)
        .opacity(canSubmit ? 1 : 0.45)
    }

    private var quickInputLegend: some View {
        VStack(alignment: .leading, spacing: 7) {
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
                .help(String(localized: "クイック入力のヒントを非表示"))
            }

            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
                GridRow {
                    legendItem(shortcut: "[ ]", label: String(localized: "チェック"))
                    legendItem(shortcut: "@", label: String(localized: "分野"))
                    legendItem(shortcut: "!", label: String(localized: "優先度"))
                }

                GridRow {
                    legendItem(shortcut: "[1b]", label: String(localized: "1ブロック"))
                    legendItem(shortcut: "/", label: String(localized: "日付"))
                    legendItem(shortcut: "#", label: String(localized: "タグ"))
                }

                GridRow {
                    legendItem(shortcut: "[25m]", label: String(localized: "25分"))
                    legendItem(shortcut: "9:00", label: String(localized: "時刻"))
                }
            }
        }
        .foregroundStyle(.secondary)
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9))
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(Color.primary.opacity(0.1))
        }
    }

    @ViewBuilder
    private func legendItem(shortcut: String, label: String) -> some View {
        HStack(spacing: 7) {
            Text(verbatim: shortcut)
                .font(.caption.monospaced().weight(.semibold))
                .foregroundStyle(.primary)
                .frame(minWidth: 30, alignment: .leading)
            Text(label)
                .font(.caption)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private func autocompleteSuggestions(_ suggestions: [TaskComposerAutocompleteSuggestion]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(suggestions) { suggestion in
                suggestionRow(
                    suggestion,
                    isSelected: selectedSuggestionID(in: suggestions) == suggestion.id
                )
            }
        }
        .padding(5)
        .frame(width: 320, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.primary.opacity(0.12))
        }
        .shadow(color: .black.opacity(0.16), radius: 12, y: 5)
    }

    private func autocompleteSuggestionItems(for token: String) -> [TaskComposerAutocompleteSuggestion] {
        let query = String(token.dropFirst())
        switch token.first {
        case "@": return areaAutocompleteSuggestions(query: query)
        case "#": return TaskComposerSuggestionBuilder().tags(query: query, todos: availableSuggestionTodos).map {
            TaskComposerAutocompleteSuggestion(id: "tag:\($0)", icon: "number", title: $0, action: .token("#\($0)"))
        }
        case "!", "/", "[":
            return TaskQuickInputOption.suggestions(for: token).map {
                TaskComposerAutocompleteSuggestion(
                    id: $0.id, icon: $0.systemImage, title: $0.title,
                    detail: $0.token, action: .token($0.token)
                )
            }
        default: return []
        }
    }

    private func areaAutocompleteSuggestions(query: String) -> [TaskComposerAutocompleteSuggestion] {
        let matches = TaskComposerSuggestionBuilder().areas(
            query: query, areas: areas, todos: availableSuggestionTodos
        )
        return matches.map { area in
            TaskComposerAutocompleteSuggestion(
                id: "area:\(area.id.uuidString)",
                symbol: area.symbolName,
                title: area.name,
                action: .area(area.id)
            )
        }
    }

    private func suggestionRow(
        _ suggestion: TaskComposerAutocompleteSuggestion,
        isSelected: Bool
    ) -> some View {
        Button {
            activateAutocompleteSuggestion(suggestion)
        } label: {
            HStack(spacing: 9) {
                if let icon = suggestion.icon {
                    Image(systemName: icon)
                        .frame(width: 18)
                } else if let symbol = suggestion.symbol {
                    Text(symbol)
                        .frame(width: 18)
                }
                Text(suggestion.title)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if let detail = suggestion.detail {
                    Text(verbatim: detail)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 32)
            .contentShape(Rectangle())
            .background(
                isSelected ? Color.accentColor.opacity(0.18) : Color.clear,
                in: RoundedRectangle(cornerRadius: 7)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { isHovering in
            if isHovering {
                selectedAutocompleteSuggestionID = suggestion.id
            }
        }
    }

    private func selectedSuggestionID(in suggestions: [TaskComposerAutocompleteSuggestion]) -> String? {
        if let selectedAutocompleteSuggestionID,
           suggestions.contains(where: { $0.id == selectedAutocompleteSuggestionID }) {
            return selectedAutocompleteSuggestionID
        }
        return suggestions.first?.id
    }

    private func moveAutocompleteSelection(by offset: Int) -> Bool {
        let suggestions = activeAutocompleteSuggestions
        guard !suggestions.isEmpty else { return false }
        let currentID = selectedSuggestionID(in: suggestions)
        let currentIndex = suggestions.firstIndex { $0.id == currentID } ?? 0
        let nextIndex = min(max(currentIndex + offset, 0), suggestions.count - 1)
        selectedAutocompleteSuggestionID = suggestions[nextIndex].id
        return true
    }

    private func activateSelectedAutocompleteSuggestion() -> Bool {
        let suggestions = activeAutocompleteSuggestions
        guard let selectedID = selectedSuggestionID(in: suggestions),
              let suggestion = suggestions.first(where: { $0.id == selectedID }) else {
            return false
        }
        activateAutocompleteSuggestion(suggestion)
        return true
    }

    private func activateAutocompleteSuggestion(_ suggestion: TaskComposerAutocompleteSuggestion) {
        switch suggestion.action {
        case .area(let id):
            guard let area = areas.first(where: { $0.id == id }) else { return }
            choose(area)
        case .token(let token):
            completeAutocompleteToken(token)
        case .title(let value):
            title = value
            isFocused = true
        }
        selectedAutocompleteSuggestionID = nil
    }

    private func unresolvedAreaActions(name: String) -> some View {
        HStack(spacing: 8) {
            Button(String(localized: "その他として追加")) {
                selectedAreaID = nil
                hasExplicitArea = true
                removeAreaToken(named: name)
                pendingAreaName = nil
                parserMessage = nil
                if onSubmit() {
                    clearInlineTokensAfterSubmission()
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private func parseCommittedTokens(in input: String) {
        guard !isApplyingParserResult else { return }
        let result = parser.parse(
            input,
            areas: parserAreas,
            anchorDate: dayBoundary.day(containing: .now, calendar: calendar),
            calendar: calendar,
            consumeTrailingToken: false
        )
        apply(result)
    }

    private func apply(_ result: TaskQuickInputParseResult) {
        isApplyingParserResult = true
        defer { isApplyingParserResult = false }

        recordInlineTokens(from: result)
        if title != result.title {
            title = result.title
        }
        if let measurement = result.measurement {
            let amount = max(1, result.plannedAmount ?? 1)
            switch measurement {
            case .checkbox: volume = .checkbox
            case .focusBlocks: volume = .blocks(amount)
            case .minutes: volume = .minutes(amount)
            }
        }
        if let areaID = result.areaID {
            selectedAreaID = areaID
            hasExplicitArea = true
        }
        if let priority = result.priority {
            self.priority = priority
            isRoomIfPossible = result.isRoomIfPossible ?? false
            hasExplicitPriority = true
        }
        if allowsDateSelection, let date = result.date {
            dateOption = quickDate(for: date)
            hasExplicitDate = true
        }
        if let time = result.timeMinutes {
            if timeMinutes == nil { reminderEnabled = true }
            timeMinutes = time
        }
        clearTimingIfUndated()
        hashtags = TodoHashtagNormalizer.normalize(hashtags + result.hashtags)
    }

    private func choose(_ area: Area) {
        guard let query = parser.trailingAreaQuery(in: title) else { return }
        removeAreaToken(named: query)
        selectedAreaID = area.id
        hasExplicitArea = true
        replaceInlineToken(.area(area.id))
        parserMessage = nil
    }

    private func completeAutocompleteToken(_ token: String) {
        title = parser.replacingTrailingAutocompleteToken(in: title, with: "\(token) ")
        parseCommittedTokens(in: title)
        isFocused = true
    }

    private func recordInlineTokens(from result: TaskQuickInputParseResult) {
        if let measurement = result.measurement {
            replaceInlineToken(.measurement(measurement, result.plannedAmount))
        }
        if let areaID = result.areaID {
            replaceInlineToken(.area(areaID))
        }
        if let priority = result.priority {
            replaceInlineToken(.priority(priority, result.isRoomIfPossible ?? false))
        }
        if allowsDateSelection, let date = result.date {
            replaceInlineToken(.date(quickDate(for: date)))
        }
        for hashtag in result.hashtags {
            replaceInlineToken(.hashtag(hashtag))
        }
    }

    private func replaceInlineToken(_ token: TaskComposerInlineToken) {
        inlineTokens.removeAll { $0.id == token.id }
        inlineTokens.append(token)
    }

    private func updateExistingInlineToken(_ token: TaskComposerInlineToken?, id: String? = nil) {
        let targetID = id ?? token?.id
        guard let targetID, inlineTokens.contains(where: { $0.id == targetID }) else { return }
        inlineTokens.removeAll { $0.id == targetID }
        if let token {
            inlineTokens.append(token)
        }
    }

    private func clearInlineTokensAfterSubmission() {
        if trimmedTitle.isEmpty {
            inlineTokens = []
            hasExplicitArea = false
            hasExplicitPriority = false
            hasExplicitDate = false
        }
    }

    private func removeInlineToken(_ token: TaskComposerInlineToken) {
        inlineTokens.removeAll { $0.id == token.id }
        switch token {
        case .measurement:
            volume = .unspecified
        case .area:
            selectedAreaID = nil
            hasExplicitArea = false
        case .priority:
            priority = .medium
            isRoomIfPossible = false
            hasExplicitPriority = false
        case .date:
            dateOption = .today
            hasExplicitDate = false
        case .hashtag(let hashtag):
            hashtags.removeAll { $0.caseInsensitiveCompare(hashtag) == .orderedSame }
        }
        isFocused = true
    }

    private func quickDate(for date: TaskQuickInputDate) -> QuickTodoDate {
        switch date {
        case .scheduled(let value):
            let today = dayBoundary.day(containing: .now, calendar: calendar)
            if calendar.isDate(value, inSameDayAs: today) { return .today }
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
               calendar.isDate(value, inSameDayAs: tomorrow) {
                return .tomorrow
            }
            return .custom(value)
        case .noDate:
            return .none
        }
    }

    private func inlineTokenView(_ token: TaskComposerInlineToken) -> some View {
        HStack(spacing: 5) {
            inlineTokenIcon(token)
            Text(inlineTokenLabel(token))
            Image(systemName: "xmark")
                .font(.system(size: 7, weight: .bold))
                .opacity(0.7)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(inlineTokenTint(token))
        .padding(.horizontal, 9)
        .frame(height: 26)
        .background(inlineTokenTint(token).opacity(0.12), in: Capsule())
        .overlay {
            Capsule().strokeBorder(inlineTokenTint(token).opacity(0.2), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func inlineTokenIcon(_ token: TaskComposerInlineToken) -> some View {
        switch token {
        case .measurement(let measurement, _):
            Image(systemName: measurement == .checkbox ? "square" :
                (measurement == .focusBlocks ? "circle" : "circle.lefthalf.filled"))
        case .area(let id):
            Text(areas.first(where: { $0.id == id })?.symbolName ?? "@")
        case .priority:
            Image(systemName: "exclamationmark")
        case .date:
            Image(systemName: "calendar")
        case .hashtag:
            Image(systemName: "number")
        }
    }

    private func inlineTokenLabel(_ token: TaskComposerInlineToken) -> String {
        switch token {
        case .measurement(let measurement, let amount):
            switch measurement {
            case .checkbox:
                return String(localized: "チェック")
            case .focusBlocks:
                return "\(max(1, amount ?? 1)) \(String(localized: "ブロック"))"
            case .minutes:
                return "\(max(1, amount ?? 1)) \(String(localized: "分"))"
            }
        case .area(let id):
            return areas.first(where: { $0.id == id })?.name ?? String(localized: "分野")
        case .priority(let priority, let later):
            return later ? String(localized: "余裕があれば") : priority.displayName
        case .date(let date):
            return date.chipLabel
        case .hashtag(let hashtag):
            return "#\(hashtag)"
        }
    }

    private func inlineTokenTint(_ token: TaskComposerInlineToken) -> Color {
        if case .area(let id) = token,
           let area = areas.first(where: { $0.id == id }),
           !DefaultAreas.isTaskInbox(area) {
            return Color(hex: area.colorHex)
        }
        return .accentColor
    }

    private func removeAreaToken(named name: String) {
        let target = "@\(name)"
        title = title
            .split(whereSeparator: \.isWhitespace)
            .filter { String($0).caseInsensitiveCompare(target) != .orderedSame }
            .joined(separator: " ")
    }
}

private struct TaskComposerAutocompleteSuggestion: Identifiable {
    enum Action {
        case area(UUID)
        case token(String)
        case title(String)
    }

    let id: String
    var icon: String?
    var symbol: String?
    let title: String
    var detail: String?
    let action: Action
}

private enum TaskComposerInlineToken: Equatable, Identifiable {
    case measurement(TodoMeasurement, Int?)
    case area(UUID)
    case priority(TodoPriority, Bool)
    case date(QuickTodoDate)
    case hashtag(String)

    var id: String {
        switch self {
        case .measurement: "measurement"
        case .area: "area"
        case .priority: "priority"
        case .date: "date"
        case .hashtag(let value): "hashtag:\(value.lowercased(with: Locale(identifier: "en_US_POSIX")))"
        }
    }

    func hashtagMatches(_ value: String) -> Bool {
        guard case .hashtag(let hashtag) = self else { return false }
        return hashtag.caseInsensitiveCompare(value) == .orderedSame
    }
}
#endif
