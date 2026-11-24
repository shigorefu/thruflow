#if os(iOS)
import SwiftUI

struct IOSFlowTimelineSegmentPopover: View {
    @Environment(\.locale) private var locale

    let segment: FlowDashboardSegment
    let onOpenHistory: (() -> Void)?

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
                        .lineLimit(2)
                    Text(segment.areaName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if segment.isActive {
                    Text(String(localized: "実行中"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color(hex: segment.colorHex))
                }
            }

            Divider()

            detail(
                String(localized: "時間"),
                value: IOSFlowTimelineFormat.interval(segment, locale: locale),
                systemImage: "clock"
            )
            detail(
                String(localized: "集中"),
                value: IOSFlowTimelineFormat.duration(segment.focusSeconds),
                systemImage: "timer"
            )
            detail(
                String(localized: "集中モード"),
                value: segment.session.mode.displayName,
                systemImage: "waveform.path"
            )

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
    }

    private func detail(_ title: String, value: String, systemImage: String) -> some View {
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

struct IOSFlowTimelineBreakPopover: View {
    @Environment(\.locale) private var locale

    let flowBreak: FlowDashboardBreak
    let onOpenHistory: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 42, height: 42)
                    .background(Color.gray.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(flowBreak.isLongBreak ? String(localized: "長休憩") : String(localized: "休憩"))
                    .font(.headline)
            }

            Divider()

            detail(
                String(localized: "時間"),
                value: IOSFlowTimelineFormat.interval(
                    from: flowBreak.startedAt,
                    to: flowBreak.endedAt,
                    locale: locale
                ),
                systemImage: "clock"
            )
            detail(
                String(localized: "休憩時間"),
                value: IOSFlowTimelineFormat.duration(flowBreak.durationSeconds),
                systemImage: "cup.and.saucer"
            )

            Button(action: onOpenHistory) {
                Label(String(localized: "詳細"), systemImage: "arrow.up.forward.app")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .frame(width: 290)
    }

    private func detail(_ title: String, value: String, systemImage: String) -> some View {
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

enum IOSFlowTimelineFormat {
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
        return remainingSeconds == 0
            ? String(localized: "\(minutes)分")
            : String(localized: "\(minutes)分\(remainingSeconds)秒")
    }
}
#endif
