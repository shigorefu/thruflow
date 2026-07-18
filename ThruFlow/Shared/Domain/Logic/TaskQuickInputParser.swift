import Foundation

struct TaskQuickInputDirection: Equatable, Sendable {
    let id: UUID
    let name: String
}

enum TaskQuickInputDate: Equatable {
    case scheduled(Date)
    case noDate
}

enum TaskQuickInputTokenKind: Equatable {
    case measurement(TodoMeasurement, plannedAmount: Int?)
    case direction(UUID)
    case unresolvedDirection(String)
    case priority(TodoPriority, isRoomIfPossible: Bool)
    case date(TaskQuickInputDate)
    case hashtag(String)
    case unrecognized
}

struct TaskQuickInputToken: Equatable {
    let rawValue: String
    let range: Range<String.Index>
    let kind: TaskQuickInputTokenKind
}

struct TaskQuickInputParseResult: Equatable {
    let title: String
    let tokens: [TaskQuickInputToken]
    let measurement: TodoMeasurement?
    let plannedAmount: Int?
    let directionID: UUID?
    let unresolvedDirection: String?
    let priority: TodoPriority?
    let isRoomIfPossible: Bool?
    let date: TaskQuickInputDate?
    let hashtags: [String]

    var recognizedTokens: [TaskQuickInputToken] {
        tokens.filter {
            if case .unrecognized = $0.kind { return false }
            if case .unresolvedDirection = $0.kind { return false }
            return true
        }
    }
}

struct TaskQuickInputParser {
    func parse(
        _ input: String,
        directions: [TaskQuickInputDirection] = [],
        anchorDate: Date = .now,
        calendar: Calendar = .current,
        consumeTrailingToken: Bool = true
    ) -> TaskQuickInputParseResult {
        let ranges = tokenRanges(in: input)
        var tokens: [TaskQuickInputToken] = []
        var consumedRanges: [Range<String.Index>] = []
        var measurement: TodoMeasurement?
        var plannedAmount: Int?
        var directionID: UUID?
        var unresolvedDirection: String?
        var priority: TodoPriority?
        var isRoomIfPossible: Bool?
        var parsedDate: TaskQuickInputDate?
        var hashtags: [String] = []

        for range in ranges {
            let rawValue = String(input[range])
            let isTrailing = range.upperBound == input.endIndex
            let canConsume = consumeTrailingToken || !isTrailing
            let kind = classify(
                rawValue,
                directions: directions,
                anchorDate: anchorDate,
                calendar: calendar
            )
            tokens.append(TaskQuickInputToken(rawValue: rawValue, range: range, kind: kind))

            guard canConsume else { continue }
            switch kind {
            case .measurement(let value, let amount):
                measurement = value
                plannedAmount = amount
                consumedRanges.append(range)
            case .direction(let id):
                directionID = id
                unresolvedDirection = nil
                consumedRanges.append(range)
            case .unresolvedDirection(let query):
                unresolvedDirection = query
            case .priority(let value, let later):
                priority = value
                isRoomIfPossible = later
                consumedRanges.append(range)
            case .date(let value):
                parsedDate = value
                consumedRanges.append(range)
            case .hashtag(let value):
                hashtags.append(value)
                consumedRanges.append(range)
            case .unrecognized:
                break
            }
        }

        return TaskQuickInputParseResult(
            title: removing(ranges: consumedRanges, from: input),
            tokens: tokens,
            measurement: measurement,
            plannedAmount: plannedAmount,
            directionID: directionID,
            unresolvedDirection: unresolvedDirection,
            priority: priority,
            isRoomIfPossible: isRoomIfPossible,
            date: parsedDate,
            hashtags: TodoHashtagNormalizer.normalize(hashtags)
        )
    }

    func trailingDirectionQuery(in input: String) -> String? {
        guard let token = trailingAutocompleteToken(in: input) else { return nil }
        guard token.hasPrefix("@") else { return nil }
        return String(token.dropFirst())
    }

    func trailingAutocompleteToken(in input: String) -> String? {
        guard let range = trailingTokenRange(in: input) else { return nil }
        let token = String(input[range])
        guard token.first.map({ "@!/[".contains($0) }) == true else { return nil }
        return token
    }

    func replacingTrailingAutocompleteToken(in input: String, with replacement: String) -> String {
        guard let range = trailingTokenRange(in: input) else { return input }
        var output = input
        output.replaceSubrange(range, with: replacement)
        return output
    }

    private func classify(
        _ rawValue: String,
        directions: [TaskQuickInputDirection],
        anchorDate: Date,
        calendar: Calendar
    ) -> TaskQuickInputTokenKind {
        if let measurement = measurementToken(rawValue) {
            return measurement
        }
        if rawValue.hasPrefix("@") {
            let query = String(rawValue.dropFirst())
            guard !query.isEmpty else { return .unresolvedDirection(query) }
            let matches = directions.filter {
                $0.name.compare(query, options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX")) == .orderedSame
            }
            return matches.count == 1 ? .direction(matches[0].id) : .unresolvedDirection(query)
        }
        if let priority = priorityToken(rawValue) {
            return priority
        }
        if let date = dateToken(rawValue, anchorDate: anchorDate, calendar: calendar) {
            return .date(date)
        }
        if rawValue.hasPrefix("#"), rawValue.count > 1 {
            return .hashtag(String(rawValue.dropFirst()))
        }
        return .unrecognized
    }

    private func measurementToken(_ rawValue: String) -> TaskQuickInputTokenKind? {
        guard rawValue.first == "[", rawValue.last == "]" else { return nil }
        let body = rawValue.dropFirst().dropLast().trimmingCharacters(in: .whitespacesAndNewlines)
        if body.isEmpty {
            return .measurement(.checkbox, plannedAmount: nil)
        }

        let pattern = #"^(\d+)\s*([\p{L}]+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: body, range: NSRange(body.startIndex..., in: body)),
              let amountRange = Range(match.range(at: 1), in: body),
              let unitRange = Range(match.range(at: 2), in: body),
              let amount = Int(body[amountRange]), amount > 0 else {
            return nil
        }

        let unit = String(body[unitRange]).lowercased(with: Locale(identifier: "en_US_POSIX"))
        let blockUnits: Set<String> = ["b", "block", "blocks", "\u{30D6}\u{30ED}\u{30C3}\u{30AF}", "б", "блок", "блока", "блоков"]
        let minuteUnits: Set<String> = ["m", "min", "mins", "minute", "minutes", "\u{5206}", "м", "мин", "минута", "минуты", "минут"]
        if blockUnits.contains(unit) {
            return .measurement(.focusBlocks, plannedAmount: amount)
        }
        if minuteUnits.contains(unit) {
            return .measurement(.minutes, plannedAmount: amount)
        }
        return nil
    }

    private func priorityToken(_ rawValue: String) -> TaskQuickInputTokenKind? {
        guard rawValue.hasPrefix("!") else { return nil }
        let value = String(rawValue.dropFirst()).lowercased(with: Locale(identifier: "en_US_POSIX"))
        if ["high", "h", "\u{9AD8}", "высокий", "в"].contains(value) {
            return .priority(.high, isRoomIfPossible: false)
        }
        if ["medium", "m", "\u{4E2D}", "средний", "с"].contains(value) {
            return .priority(.medium, isRoomIfPossible: false)
        }
        if ["low", "l", "\u{4F4E}", "низкий", "н"].contains(value) {
            return .priority(.low, isRoomIfPossible: false)
        }
        if ["later", "n", "\u{4F59}\u{88D5}", "потом", "позже", "п"].contains(value) {
            return .priority(.low, isRoomIfPossible: true)
        }
        return nil
    }

    private func dateToken(_ rawValue: String, anchorDate: Date, calendar: Calendar) -> TaskQuickInputDate? {
        guard rawValue.hasPrefix("/") else { return nil }
        let value = String(rawValue.dropFirst()).lowercased(with: Locale(identifier: "en_US_POSIX"))
        let start = calendar.startOfDay(for: anchorDate)

        if ["today", "\u{4ECA}\u{65E5}", "сегодня"].contains(value) {
            return .scheduled(start)
        }
        if ["tomorrow", "\u{660E}\u{65E5}", "завтра"].contains(value),
           let date = calendar.date(byAdding: .day, value: 1, to: start) {
            return .scheduled(date)
        }
        if ["nodate", "no-date", "\u{65E5}\u{4ED8}\u{306A}\u{3057}", "без-даты", "без_даты"].contains(value) {
            return .noDate
        }
        if let date = isoDate(value, calendar: calendar) {
            return .scheduled(date)
        }

        let weekdays: [Int: Set<String>] = [
            1: ["sun", "sunday", "\u{65E5}", "вс", "воскресенье"],
            2: ["mon", "monday", "\u{6708}", "пн", "понедельник"],
            3: ["tue", "tues", "tuesday", "\u{706B}", "вт", "вторник"],
            4: ["wed", "wednesday", "\u{6C34}", "ср", "среда"],
            5: ["thu", "thur", "thurs", "thursday", "\u{6728}", "чт", "четверг"],
            6: ["fri", "friday", "\u{91D1}", "пт", "пятница"],
            7: ["sat", "saturday", "\u{571F}", "сб", "суббота"],
        ]
        guard let weekday = weekdays.first(where: { $0.value.contains(value) })?.key else { return nil }
        let currentWeekday = calendar.component(.weekday, from: start)
        let offset = (weekday - currentWeekday + 7) % 7
        guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
        return .scheduled(date)
    }

    private func isoDate(_ value: String, calendar: Calendar) -> Date? {
        let parts = value.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else { return nil }
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        guard let date = calendar.date(from: components),
              calendar.component(.year, from: date) == year,
              calendar.component(.month, from: date) == month,
              calendar.component(.day, from: date) == day else { return nil }
        return date
    }

    private func tokenRanges(in input: String) -> [Range<String.Index>] {
        let pattern = #"\[[^\]\n]*\]|\S+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: input, range: NSRange(input.startIndex..., in: input)).compactMap {
            Range($0.range, in: input)
        }
    }

    private func trailingTokenRange(in input: String) -> Range<String.Index>? {
        guard let range = tokenRanges(in: input).last,
              range.upperBound == input.endIndex else { return nil }
        return range
    }

    private func removing(ranges: [Range<String.Index>], from input: String) -> String {
        var output = input
        for range in ranges.sorted(by: { $0.lowerBound > $1.lowerBound }) {
            output.removeSubrange(range)
        }
        return output
            .split(whereSeparator: \Character.isWhitespace)
            .joined(separator: " ")
    }
}
