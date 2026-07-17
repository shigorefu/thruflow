//
//  CalendarTaskIndicators.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/17.
//

import SwiftUI

enum CalendarWeekdaySymbols {
    static func orderedAbbreviated(calendar: Calendar) -> [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let first = max(0, calendar.firstWeekday - 1)
        return Array(symbols[first...] + symbols[..<first])
    }
}

struct CalendarTaskIndicators: View {
    let todos: [Todo]
    let date: Date
    var maximumVisibleCount = 4

    @Environment(\.calendar) private var calendar

    private var scheduledTodos: [Todo] {
        todos
            .filter { todo in
                guard !todo.isArchived,
                      !todo.isDeleted,
                      let scheduledDate = todo.scheduledDate else {
                    return false
                }
                return calendar.isDate(scheduledDate, inSameDayAs: date)
            }
            .sorted { lhs, rhs in
                if lhs.isCompleted != rhs.isCompleted {
                    return !lhs.isCompleted
                }
                return lhs.sortIndex < rhs.sortIndex
            }
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(scheduledTodos.prefix(maximumVisibleCount)), id: \.id) { todo in
                Circle()
                    .fill(markerColor(for: todo))
                    .frame(width: 4, height: 4)
                    .opacity(todo.isCompleted ? 0.38 : 1)
            }
        }
        .frame(height: 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "この日のタスク、\(scheduledTodos.count)件"))
    }

    private func markerColor(for todo: Todo) -> Color {
        todo.direction.map { Color(hex: $0.colorHex) } ?? .secondary
    }
}
