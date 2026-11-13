#if os(macOS)
import SwiftData
import SwiftUI

struct HistoryBreakEditorView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    let flowBreak: FlowBreak
    let onClose: (() -> Void)?
    @State private var startTime: Date
    @State private var minutes: Int
    @State private var endTime: Date
    @State private var errorMessage: String?
    @State private var showsDeleteConfirmation = false

    private let editor = FlowBreakEditor()

    init(flowBreak: FlowBreak, onClose: (() -> Void)? = nil) {
        self.flowBreak = flowBreak
        self.onClose = onClose
        let resolvedEnd = flowBreak.resolvedEndAt(referenceDate: .now)
        let duration = resolvedEnd.timeIntervalSince(flowBreak.startedAt)
        _startTime = State(initialValue: flowBreak.startedAt)
        _minutes = State(initialValue: max(1, Int(ceil(duration / 60))))
        _endTime = State(initialValue: resolvedEnd)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                if onClose != nil {
                    Button { close() } label: {
                        Image(systemName: "chevron.left")
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(String(localized: "戻る"))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Label(flowBreak.isLongBreak ? String(localized: "長休憩") : String(localized: "休憩"), systemImage: "cup.and.saucer")
                        .font(.title3.weight(.semibold))
                }
                Spacer()

                if onClose == nil {
                    Button { close() } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(String(localized: "閉じる"))
                }
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "開始"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    DatePicker(
                        String(localized: "開始"),
                        selection: startTimeBinding,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                }

                Image(systemName: "arrow.right")
                    .foregroundStyle(.tertiary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "終了"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    DatePicker(
                        String(localized: "終了"),
                        selection: endTimeBinding,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                }

                Spacer(minLength: 8)
            }

            HStack {
                Text(String(localized: "長さ"))
                Spacer()
                TextField(String(localized: "分"), value: $minutes, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 76)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: minutes) { _, newValue in
                        guard (FlowBreakEditor.minimumDurationMinutes...FlowBreakEditor.maximumDurationMinutes)
                            .contains(newValue) else { return }
                        endTime = startTime.addingTimeInterval(TimeInterval(newValue * 60))
                    }
                Text(String(localized: "分"))
                    .foregroundStyle(.secondary)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button(role: .destructive) {
                showsDeleteConfirmation = true
            } label: {
                Label(String(localized: "休憩を削除"), systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .disabled(isActiveBreak)

            HStack {
                Button(String(localized: "キャンセル")) { close() }
                Spacer()
                Button(String(localized: "保存")) { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(minutes < FlowBreakEditor.minimumDurationMinutes || minutes > FlowBreakEditor.maximumDurationMinutes)
            }
        }
        .padding(18)
        .frame(width: 360, height: 340)
        .confirmationDialog(
            String(localized: "休憩を削除"),
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "削除"), role: .destructive) {
                guard !isActiveBreak else { return }
                do {
                    try editor.delete(flowBreak, modelContext: modelContext)
                    close()
                } catch {
                    errorMessage = String(localized: "休憩を保存できませんでした。")
                }
            }
            Button(String(localized: "キャンセル"), role: .cancel) {}
        }
    }

    private var startTimeBinding: Binding<Date> {
        Binding(
            get: { startTime },
            set: { selectedStart in
                let previousMinutes = minutes
                startTime = selectedStart
                if endTime > selectedStart {
                    minutes = editor.durationMinutes(from: selectedStart, to: endTime)
                } else {
                    minutes = previousMinutes
                }
                endTime = selectedStart.addingTimeInterval(TimeInterval(minutes * 60))
            }
        )
    }

    private var endTimeBinding: Binding<Date> {
        Binding(
            get: { endTime },
            set: { selectedEnd in
                let normalizedEnd = editor.normalizedEndTime(
                    startedAt: startTime,
                    selectedTime: selectedEnd,
                    calendar: calendar
                )
                endTime = normalizedEnd
                minutes = editor.durationMinutes(
                    from: startTime,
                    to: normalizedEnd
                )
            }
        )
    }

    private func save() {
        do {
            _ = try editor.updateInterval(
                of: flowBreak,
                startedAt: startTime,
                minutes: minutes,
                modelContext: modelContext,
                protectedSessionID: activeFlowStore.activeSession?.id
            )
            close()
        } catch FlowBreakEditorError.activeFlowWouldMove {
            errorMessage = String(localized: "進行中の集中は移動できません。")
        } catch {
            errorMessage = String(localized: "休憩を保存できませんでした。")
        }
    }

    private var isActiveBreak: Bool {
        flowBreak.timerStoppedAt == nil &&
            activeFlowStore.isBreakPhase &&
            activeFlowStore.activeSession?.id == flowBreak.previousSessionID
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }
}
#endif
