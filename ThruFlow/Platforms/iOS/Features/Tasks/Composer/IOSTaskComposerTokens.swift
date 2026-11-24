#if os(iOS)
import SwiftUI

struct IOSTaskComposerTokens: View {
    @Environment(\.calendar) private var calendar

    let tokens: [IOSTaskComposerInlineToken]
    let areas: [Area]
    let currentAppDay: Date
    let onRemove: (IOSTaskComposerInlineToken) -> Void

    @ViewBuilder
    var body: some View {
        if !tokens.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 5) {
                    ForEach(tokens) { token in
                        Button {
                            onRemove(token)
                        } label: {
                            tokenLabel(token)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            String(localized: "トークンを削除")
                        )
                    }
                }
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.move(edge: .leading).combined(with: .opacity))
        }
    }

    private func tokenLabel(_ token: IOSTaskComposerInlineToken) -> some View {
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
    private func inlineTokenIcon(_ token: IOSTaskComposerInlineToken) -> some View {
        switch token {
        case .measurement(let measurement, _):
            Image(
                systemName: measurement == .checkbox
                    ? "square"
                    : (measurement == .focusBlocks ? "circle" : "circle.lefthalf.filled")
            )
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

    private func inlineTokenLabel(_ token: IOSTaskComposerInlineToken) -> String {
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
            return inlineTokenDateLabel(date)
        case .hashtag(let hashtag):
            return "#\(hashtag)"
        }
    }

    private func inlineTokenDateLabel(_ date: Date?) -> String {
        guard let date else { return String(localized: "日付なし") }
        if calendar.isDate(date, inSameDayAs: currentAppDay) {
            return String(localized: "今日")
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: currentAppDay),
           calendar.isDate(date, inSameDayAs: tomorrow) {
            return String(localized: "明日")
        }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    private func inlineTokenTint(_ token: IOSTaskComposerInlineToken) -> Color {
        if case .area(let id) = token,
           let area = areas.first(where: { $0.id == id }),
           !DefaultAreas.isTaskInbox(area) {
            return Color(hex: area.colorHex)
        }
        return .accentColor
    }
}

enum IOSTaskComposerInlineToken: Equatable, Identifiable {
    case measurement(TodoMeasurement, Int?)
    case area(UUID)
    case priority(TodoPriority, Bool)
    case date(Date?)
    case hashtag(String)

    var id: String {
        switch self {
        case .measurement:
            "measurement"
        case .area:
            "area"
        case .priority:
            "priority"
        case .date:
            "date"
        case .hashtag(let value):
            "hashtag:\(value.lowercased(with: Locale(identifier: "en_US_POSIX")))"
        }
    }
}
#endif
