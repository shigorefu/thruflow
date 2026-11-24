import Foundation

/// Shared presentation and filtering for quick-input choices on macOS and iOS.
struct TaskQuickInputOption: Identifiable {
    let token: String
    let title: String
    let systemImage: String

    var id: String { token }

    static func suggestions(for token: String) -> [Self] {
        let options: [Self]
        switch token.first {
        case "!":
            options = [
                Self(token: "!high", title: String(localized: "高"), systemImage: "flag"),
                Self(token: "!medium", title: String(localized: "中"), systemImage: "flag"),
                Self(token: "!low", title: String(localized: "低"), systemImage: "flag"),
                Self(token: "!later", title: String(localized: "余裕があれば"), systemImage: "flag"),
            ]
        case "/":
            options = [
                Self(token: "/today", title: String(localized: "今日"), systemImage: "calendar"),
                Self(token: "/tomorrow", title: String(localized: "明日"), systemImage: "calendar"),
                Self(token: "/nodate", title: String(localized: "日付なし"), systemImage: "calendar"),
            ]
        case "[":
            options = [
                Self(token: "[]", title: String(localized: "チェック"), systemImage: "square"),
                Self(token: "[1b]", title: String(localized: "1ブロック"), systemImage: "circle"),
                Self(token: "[25m]", title: String(localized: "25分"), systemImage: "circle.lefthalf.filled"),
            ]
        default:
            return []
        }
        return options.filter { $0.token.hasPrefix(token.lowercased()) }
    }
}
