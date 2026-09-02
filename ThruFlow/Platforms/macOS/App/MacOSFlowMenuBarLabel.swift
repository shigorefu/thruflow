#if os(macOS)
import SwiftUI

struct MacOSFlowMenuBarLabel: View {
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore
    @State private var displayDate = Date.now

    var body: some View {
        if activeFlowStore.timerState == nil {
            FlowMenuIcon(width: 18)
                .accessibilityLabel(String(localized: "Flow"))
        } else {
            Text(menuTitle(now: displayDate))
                .font(.system(.body, design: .default))
                .monospacedDigit()
                .task(id: activeFlowStore.timerState?.startedAt) {
                    displayDate = .now
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(1))
                        guard !Task.isCancelled else { return }
                        displayDate = .now
                    }
                }
        }
    }

    private func menuTitle(now: Date) -> String {
        guard activeFlowStore.timerState != nil else { return String(localized: "Flow") }

        if activeFlowStore.isBreakPhase {
            let title = activeFlowStore.timerState?.isLongBreak == true ? String(localized: "長休憩") : String(localized: "休憩")
            return String(localized: "☕️ \(title) - \(activeFlowStore.remainingText(now: now))")
        }

        let session = activeFlowStore.activeSession
        let emoji = session?.area?.symbolName ?? "▶"
        return String(localized: "\(emoji): \(taskName(for: session)) - \(activeFlowStore.remainingText(now: now))")
    }

    private func taskName(for session: FlowSession?) -> String {
        if let todo = session?.todo {
            return TodoDisplay.title(for: todo)
        }

        if let areaName = session?.area?.name.trimmingCharacters(in: .whitespacesAndNewlines),
           !areaName.isEmpty {
            return areaName
        }

        return String(localized: "その他")
    }
}
#endif
