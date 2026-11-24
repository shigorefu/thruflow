#if os(macOS)
import SwiftUI

struct TasksCalendarWorkspace<Content: View>: View {
    let title: String
    let snapshot: TaskCalendarSnapshot?
    let taskFilter: TaskCalendarFilter
    @Binding var calendarRange: TaskCalendarRange
    @Binding var selectedDate: Date
    let onPrevious: () -> Void
    let onToday: () -> Void
    let onNext: () -> Void
    let onDropPayload: (String, Date) -> Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                Group {
                    content()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                VStack(spacing: 0) {
                    MacCalendarNavigationHeader(
                        title: title,
                        onPrevious: onPrevious,
                        onToday: onToday,
                        onNext: onNext
                    ) {
                        taskRangePicker
                    }

                    Divider()

                    ScrollView {
                        taskPeriodPicker
                            .padding(16)
                    }

                    Spacer(minLength: 0)
                }
                .frame(
                    width: MacCalendarSidebarLayout.width(
                        for: title,
                        in: geometry.size.width,
                        preferredFraction: 0.29,
                        minimum: 300
                    )
                )
                .background(Color.secondary.opacity(0.035))
            }
        }
    }

    private var taskRangePicker: some View {
        Picker(String(localized: "表示範囲"), selection: $calendarRange) {
            ForEach(TaskCalendarRange.allCases) { option in
                Text(option.displayName).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .accessibilityLabel(String(localized: "表示範囲"))
    }

    @ViewBuilder
    private var taskPeriodPicker: some View {
        switch calendarRange {
        case .oneDay:
            HistoryMiniCalendar(
                selectedDate: $selectedDate,
                indicatorSource: .tasks(taskFilter),
                taskSnapshot: snapshot,
                onDropPayload: onDropPayload
            )
        case .sevenDays:
            HistoryMiniCalendar(
                selectedDate: $selectedDate,
                selectionMode: .week,
                indicatorSource: .tasks(taskFilter),
                taskSnapshot: snapshot,
                onDropPayload: onDropPayload
            )
        case .month:
            HistoryYearMonthPicker(selectedDate: $selectedDate)
        }
    }
}
#endif
