#if os(macOS)
import SwiftData
import SwiftUI

struct HistoryDayInspectorPane: View {
    @Binding var selectedDate: Date
    let selectedItem: HistoryCalendarItem?
    @Binding var manualFlowDraft: HistoryFlowCreationDraft?
    let sidebarHeader: AnyView
    let historySessions: [FlowSession]
    let onEdit: (HistoryCalendarItem) -> Void
    let onDropOnDay: (String, Date) -> Bool

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader

            Divider()

            HistoryMiniCalendar(
                selectedDate: $selectedDate,
                historySessions: historySessions,
                onDropPayload: onDropOnDay
            )
                .padding(16)

            Divider()

            if let draft = manualFlowDraft {
                ManualFlowCreationView(
                    startedAt: draft.startedAt,
                    onTimeChange: updateManualFlowDraft
                ) {
                    manualFlowDraft = nil
                }
                .id(draft.id)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    if let selectedItem {
                        properties(selectedItem)
                            .padding(18)
                    } else {
                        ContentUnavailableView(
                            String(localized: "記録を選択"),
                            systemImage: "cursorarrow.click",
                            description: Text(String(localized: "集中記録または休憩を選ぶと、ここに詳細が表示されます。"))
                        )
                        .padding(.horizontal, 20)
                        .padding(.vertical, 44)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.secondary.opacity(0.035))
    }

    private func updateManualFlowDraft(startedAt: Date, endedAt: Date) {
        manualFlowDraft?.startedAt = startedAt
        manualFlowDraft?.endedAt = endedAt
    }

    private func properties(_ item: HistoryCalendarItem) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Text(item.symbol)
                    .font(.title2)
                    .frame(width: 42, height: 42)
                    .background(Color(hex: item.colorHex).opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.headline)
                        .lineLimit(2)
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Button {
                    onEdit(item)
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .help(String(localized: "編集"))
                .accessibilityLabel(String(localized: "編集"))
            }

            Divider()

            propertyRow(String(localized: "時間"), systemImage: "clock") {
                "\(time(item.startedAt))–\(time(item.endedAt))"
            }
            propertyRow(String(localized: "長さ"), systemImage: "timer") {
                duration(item.durationSeconds)
            }

            switch item.kind {
            case .flow:
                propertyRow(String(localized: "集中モード"), systemImage: "waveform.path") {
                    item.session?.mode.displayName ?? String(localized: "集中記録")
                }
                propertyRow(String(localized: "分野"), systemImage: ProductSymbol.area) {
                    item.subtitle
                }
            case .rest:
                propertyRow(String(localized: "種類"), systemImage: "cup.and.saucer") {
                    item.flowBreak?.isLongBreak == true ? String(localized: "長休憩") : String(localized: "休憩")
                }
            }

            if let memo = item.session?.result ?? item.todo?.notes,
               !memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label(String(localized: "メモ"), systemImage: "note.text")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(memo)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, 4)
            }

            Button {
                onEdit(item)
            } label: {
                Label(String(localized: "詳細を編集"), systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: item.colorHex))
            .padding(.top, 4)
        }
    }

    private func propertyRow(_ title: String, systemImage: String, value: () -> String) -> some View {
        HStack(spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value())
                .font(.callout.weight(.medium).monospacedDigit())
                .multilineTextAlignment(.trailing)
        }
    }

    private func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private func duration(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        if minutes < 60 { return String(localized: "\(minutes)分") }
        return String(localized: "\(minutes / 60)時間\(minutes % 60)分")
    }
}
#endif
