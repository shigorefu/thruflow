#if os(iOS)
import SwiftUI

struct IOSDashboardAchievementPage: View {
    let todoGroups: FlowDashboardTodoGroups

    var body: some View {
        let standardTodos = todoGroups.standard
        let habitTodos = todoGroups.habits
        let niceTodos = todoGroups.nice
        let required = standardTodos + habitTodos
        let completed = required.filter(\.isCompleted).count
        let ratio = required.isEmpty ? 0 : Double(completed) / Double(required.count)

        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 16)
                Circle()
                    .inset(by: 8)
                    .trim(from: 0, to: ratio)
                    .stroke(
                        Color.accentColor,
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                Text(ratio, format: .percent.precision(.fractionLength(0)))
                    .font(.largeTitle.bold())
                    .monospacedDigit()
            }
            .frame(width: 160, height: 160)

            achievementRow(
                String(localized: "タスク"),
                completed: standardTodos.filter(\.isCompleted).count,
                total: standardTodos.count
            )
            achievementRow(
                String(localized: "習慣一覧"),
                completed: habitTodos.filter(\.isCompleted).count,
                total: habitTodos.count
            )
            if !niceTodos.isEmpty {
                achievementRow(
                    String(localized: "ナイス"),
                    completed: niceTodos.filter(\.isCompleted).count,
                    total: niceTodos.count
                )
            }

            Text(String(localized: "今日の達成 \(completed) / \(required.count)"))
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    private func achievementRow(_ title: String, completed: Int, total: Int) -> some View {
        HStack {
            Text(title)
                .font(.callout)
            Spacer()
            Text("\(completed) / \(total)")
                .font(.callout.weight(.semibold))
                .monospacedDigit()
        }
    }
}
#endif
