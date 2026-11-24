#if os(macOS)
import SwiftData
import SwiftUI

struct TimelineSegmentHoverCard: View {
    @Environment(\.locale) private var locale

    let segment: FlowDashboardSegment

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(segment.symbol) \(segment.taskTitle)")
                .font(.caption.weight(.semibold))
                .lineLimit(1)

            Text("\(TimelineSegmentFormat.interval(segment, locale: locale)) · \(TimelineSegmentFormat.duration(segment.focusSeconds))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(width: 190, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(Color.primary.opacity(0.12))
        }
        .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
    }
}

struct TimelineBreakHoverCard: View {
    @Environment(\.locale) private var locale

    let flowBreak: FlowDashboardBreak

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(flowBreak.isLongBreak ? String(localized: "長休憩") : String(localized: "休憩"), systemImage: "cup.and.saucer.fill")
                .font(.caption.weight(.semibold))

            Text("\(TimelineSegmentFormat.interval(from: flowBreak.startedAt, to: flowBreak.endedAt, locale: locale)) · \(TimelineSegmentFormat.duration(flowBreak.durationSeconds))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(width: 190, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(Color.primary.opacity(0.12))
        }
        .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
    }
}

struct TimelineBreakPopover: View {
    @Environment(\.locale) private var locale

    let flowBreak: FlowDashboardBreak
    let onSave: (Int) throws -> FlowBreakEditResult

    @State private var minutes: Int
    @State private var errorText: String?

    init(
        flowBreak: FlowDashboardBreak,
        onSave: @escaping (Int) throws -> FlowBreakEditResult
    ) {
        self.flowBreak = flowBreak
        self.onSave = onSave
        _minutes = State(initialValue: max(1, Int(ceil(Double(flowBreak.durationSeconds) / 60))))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 42, height: 42)
                    .background(Color.gray.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(flowBreak.isLongBreak ? String(localized: "長休憩") : String(localized: "休憩"))
                        .font(.headline)
                    Text(String(localized: "開始時刻は固定されます"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack {
                Label(String(localized: "開始"), systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(TimelineSegmentFormat.time(flowBreak.startedAt, locale: locale))
                    .monospacedDigit()
            }

            HStack {
                Label(String(localized: "終了"), systemImage: "clock.badge.checkmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(TimelineSegmentFormat.time(adjustedEndAt, locale: locale))
                    .monospacedDigit()
            }

            HStack(spacing: 8) {
                Text(String(localized: "休憩時間"))
                    .font(.callout.weight(.medium))
                Spacer()
                TextField(String(localized: "分"), value: $minutes, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(width: 76)
                    .onSubmit(save)
                Text(String(localized: "分"))
                    .foregroundStyle(.secondary)
            }

            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: save) {
                Text(String(localized: "保存"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(minutes < FlowBreakEditor.minimumDurationMinutes || minutes > FlowBreakEditor.maximumDurationMinutes)
        }
        .padding(16)
        .frame(width: 290)
    }

    private var adjustedEndAt: Date {
        flowBreak.startedAt.addingTimeInterval(TimeInterval(max(0, minutes) * 60))
    }

    private func save() {
        do {
            _ = try onSave(minutes)
            errorText = nil
        } catch FlowBreakEditorError.activeFlowWouldMove {
            errorText = String(localized: "実行中のFlowは移動できません。現在のFlowを終了してから編集してください。")
        } catch {
            errorText = String(localized: "休憩時間を保存できませんでした。")
        }
    }
}

struct TimelineSegmentPopover: View {
    @Environment(\.locale) private var locale

    let segment: FlowDashboardSegment
    let onDelete: (() -> Void)?
    let onOpenHistory: (() -> Void)?

    @State private var showsDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Text(segment.symbol)
                    .font(.title2)
                    .frame(width: 42, height: 42)
                    .background(Color(hex: segment.colorHex).opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(segment.taskTitle)
                        .font(.headline)
                    Text(segment.areaName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                if segment.isActive {
                    Text(String(localized: "実行中"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color(hex: segment.colorHex))
                } else if onDelete != nil {
                    Button {
                        showsDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash.fill")
                            .font(.callout.weight(.semibold))
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                    .help(String(localized: "この区間を削除"))
                    .accessibilityLabel(String(localized: "このFlow区間を削除"))
                }
            }

            Divider()

            segmentDetail(String(localized: "時間"), value: TimelineSegmentFormat.interval(segment, locale: locale), systemImage: "clock")
            segmentDetail(String(localized: "集中"), value: TimelineSegmentFormat.duration(segment.focusSeconds), systemImage: "timer")
            segmentDetail(String(localized: "集中モード"), value: segment.session.mode.displayName, systemImage: "waveform.path")

            if let onOpenHistory {
                Button(action: onOpenHistory) {
                    Label(String(localized: "Flow履歴を開く"), systemImage: "arrow.up.forward.app")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: segment.colorHex))
            }
        }
        .padding(16)
        .frame(width: 290)
        .confirmationDialog(
            String(localized: "このFlow区間を削除しますか？"),
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "削除"), role: .destructive) {
                onDelete?()
            }
            Button(String(localized: "キャンセル"), role: .cancel) {}
        } message: {
            Text(String(localized: "この区間の集中時間がタスクと方向の進捗から差し引かれます。"))
        }
    }

    private func segmentDetail(_ title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.callout.weight(.medium))
                .monospacedDigit()
        }
    }
}

enum TimelineSegmentFormat {
    static func interval(_ segment: FlowDashboardSegment, locale: Locale) -> String {
        interval(from: segment.startedAt, to: segment.endedAt, locale: locale)
    }

    static func interval(from start: Date, to end: Date, locale: Locale) -> String {
        "\(time(start, locale: locale))–\(time(end, locale: locale))"
    }

    static func time(_ date: Date, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("jm")
        return formatter.string(from: date)
    }

    static func duration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return remainingSeconds == 0 ? String(localized: "\(minutes)分") : String(localized: "\(minutes)分\(remainingSeconds)秒")
    }
}
#endif
