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
                .accessibilityLabel(String(localized: "Flow"))
        } else {
            Text(menuTitle)
                .font(.system(.body, design: .default))
                .monospacedDigit()
        }
    }

    private var menuTitle: String {
        guard activeFlowStore.timerState != nil else { return String(localized: "Flow") }

        if activeFlowStore.isBreakPhase {
            let title = activeFlowStore.timerState?.isLongBreak == true ? String(localized: "Long Break") : String(localized: "休憩")
            return String(localized: "☕️ \(title) - \(activeFlowStore.remainingText(now: activeFlowStore.displayDate))")
        }

        let session = activeFlowStore.activeSession
        let emoji = session?.direction?.symbolName ?? "▶"
        return String(localized: "\(emoji): \(taskName(for: session)) - \(activeFlowStore.remainingText(now: activeFlowStore.displayDate))")
    }

    private func taskName(for session: FlowSession?) -> String {
        if let todo = session?.todo {
            return TodoDisplay.title(for: todo)
        }

        if let directionName = session?.direction?.name.trimmingCharacters(in: .whitespacesAndNewlines),
           !directionName.isEmpty {
            return directionName
        }

        return String(localized: "その他")
    }
}
#endif
