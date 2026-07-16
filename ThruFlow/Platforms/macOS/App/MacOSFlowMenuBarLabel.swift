#if os(macOS)
import SwiftUI

struct MacOSFlowMenuBarLabel: View {
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    var body: some View {
        if activeFlowStore.timerState == nil {
            Image("FlowMenuBarIcon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 13)
                .accessibilityLabel("Flow")
        } else {
            Text(menuTitle)
                .font(.system(.body, design: .default))
                .monospacedDigit()
        }
    }

    private var menuTitle: String {
        guard activeFlowStore.timerState != nil else { return "Flow" }

        if activeFlowStore.isBreakPhase {
            let title = activeFlowStore.timerState?.isLongBreak == true ? "Long Break" : "休憩"
            return "☕️ \(title) - \(activeFlowStore.remainingText(now: activeFlowStore.displayDate))"
        }

        let session = activeFlowStore.activeSession
        let emoji = session?.direction?.symbolName ?? "▶"
        return "\(emoji): \(taskName(for: session)) - \(activeFlowStore.remainingText(now: activeFlowStore.displayDate))"
    }

    private func taskName(for session: FlowSession?) -> String {
        if let todo = session?.todo {
            return TodoDisplay.title(for: todo)
        }

        if let directionName = session?.direction?.name.trimmingCharacters(in: .whitespacesAndNewlines),
           !directionName.isEmpty {
            return directionName
        }

        return "その他"
    }
}
#endif
