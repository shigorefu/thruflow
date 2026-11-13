#if os(macOS)
import SwiftData
import SwiftUI

/// Quick-add volume selection for the composer. `checkbox` means "no target amount",
/// `blocks(n)` targets `n` focus blocks (1 Block = 25 focused minutes).
enum QuickTodoVolume: Hashable {
    case unspecified
    case checkbox
    case blocks(Int)
    case minutes(Int)

    var measurement: TodoMeasurement {
        switch self {
        case .unspecified, .checkbox:
            .checkbox
        case .blocks:
            .focusBlocks
        case .minutes:
            .minutes
        }
    }

    var plannedAmount: Int? {
        switch self {
        case .unspecified, .checkbox:
            nil
        case .blocks(let count), .minutes(let count):
            count
        }
    }

    var menuLabel: String {
        switch self {
        case .unspecified:
            String(localized: "種類")
        case .checkbox:
            String(localized: "チェックのみ")
        case .blocks(let count):
            count == 1 ? String(localized: "1 Block") : String(localized: "\(count) Blocks")
        case .minutes(let count):
            String(localized: "\(count)分")
        }
    }

    var chipLabel: String {
        switch self {
        case .unspecified:
            String(localized: "種類")
        case .checkbox:
            String(localized: "チェック")
        case .blocks(let count):
            count == 1 ? String(localized: "1 Block") : String(localized: "\(count) Blocks")
        case .minutes(let count):
            String(localized: "\(count)分")
        }
    }
}

/// Quick-add date selection for the composer.
enum QuickTodoDate: Hashable {
    case today
    case tomorrow
    case none
    case custom(Date)

    func resolvedDate(
        calendar: Calendar,
        dayBoundary: AppDayBoundary
    ) -> Date? {
        let today = dayBoundary.day(containing: .now, calendar: calendar)
        switch self {
        case .today:
            return today
        case .tomorrow:
            return calendar.date(byAdding: .day, value: 1, to: today)
        case .none:
            return nil
        case .custom(let date):
            return calendar.startOfDay(for: date)
        }
    }

    var chipLabel: String {
        switch self {
        case .today:
            String(localized: "今日")
        case .tomorrow:
            String(localized: "明日")
        case .none:
            String(localized: "日付なし")
        case .custom(let date):
            Self.formatter.string(from: date)
        }
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter
    }()
}
#endif
