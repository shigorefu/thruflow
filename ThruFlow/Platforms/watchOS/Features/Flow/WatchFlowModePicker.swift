#if os(watchOS)
import SwiftData
import SwiftUI

struct WatchFlowModePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    private let modes: [FlowMode] = [.sprint, .twentyFiveFive, .fiftyTen]

    var body: some View {
        List(modes) { mode in
            Button {
                activeFlowStore.selectMode(mode, modelContext: modelContext)
                dismiss()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mode.displayName)
                        Text(mode.blockSummary)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if activeFlowStore.selectedMode == mode {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
            }
        }
        .navigationTitle(String(localized: "Flowタイプ"))
    }
}
#endif
