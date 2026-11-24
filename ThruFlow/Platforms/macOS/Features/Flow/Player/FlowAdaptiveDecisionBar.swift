#if os(macOS)
import SwiftData
import SwiftUI

struct FlowAdaptiveDecisionBar: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    var body: some View {
        HStack(spacing: 10) {
            Text(String(localized: "次を選択"))
                .font(.headline)

            Spacer()

            if activeFlowStore.timerState?.nextAdaptiveFocusDurationSeconds != nil {
                Button(String(localized: "+\(adaptiveExtensionMinutes)分")) {
                    activeFlowStore.extendAdaptive(modelContext: modelContext)
                }
            }

            Button(String(localized: "休憩")) {
                activeFlowStore.requestBreakMemo(modelContext: modelContext)
            }

            Button(String(localized: "Flowを終了")) {
                activeFlowStore.finish(modelContext: modelContext)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var adaptiveExtensionMinutes: Int {
        guard let state = activeFlowStore.timerState,
              let next = state.nextAdaptiveFocusDurationSeconds else {
            return 0
        }

        return (next - state.plannedFocusDurationSeconds) / 60
    }
}
#endif
