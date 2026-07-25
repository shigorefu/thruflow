import SwiftUI

enum IOSPeriodStripUnit {
    case day
    case week

    var calendarComponent: Calendar.Component {
        switch self {
        case .day: .day
        case .week: .weekOfYear
        }
    }

    var itemRadius: Int {
        switch self {
        case .day: 3_650
        case .week: 520
        }
    }

    func normalized(_ date: Date, calendar: Calendar) -> Date {
        switch self {
        case .day:
            calendar.startOfDay(for: date)
        case .week:
            calendar.dateInterval(of: .weekOfYear, for: date)?.start
                ?? calendar.startOfDay(for: date)
        }
    }

    func contains(_ date: Date, selectedDate: Date, calendar: Calendar) -> Bool {
        switch self {
        case .day:
            calendar.isDate(date, inSameDayAs: selectedDate)
        case .week:
            normalized(date, calendar: calendar) == normalized(selectedDate, calendar: calendar)
        }
    }
}

struct IOSScrollablePeriodStrip<Content: View>: View {
    @Environment(\.calendar) private var calendar

    @Binding private var selectedDate: Date
    private let unit: IOSPeriodStripUnit
    private let visibleItemCount: Int
    private let spacing: CGFloat
    private let height: CGFloat
    private let content: (Date, Bool) -> Content

    @State private var anchorDate: Date
    @State private var scrollTarget: Date?
    @State private var pendingSelection: Date?
    @State private var fallbackIsDragging = false
    @State private var fallbackCommitRevision = 0

    init(
        selectedDate: Binding<Date>,
        unit: IOSPeriodStripUnit,
        visibleItemCount: Int,
        spacing: CGFloat,
        height: CGFloat,
        @ViewBuilder content: @escaping (Date, Bool) -> Content
    ) {
        _selectedDate = selectedDate
        self.unit = unit
        self.visibleItemCount = visibleItemCount
        self.spacing = spacing
        self.height = height
        self.content = content
        _anchorDate = State(initialValue: selectedDate.wrappedValue)
        _scrollTarget = State(initialValue: nil)
    }

    private var dates: [Date] {
        let reference = unit.normalized(anchorDate, calendar: calendar)
        return (-unit.itemRadius...unit.itemRadius).compactMap { offset in
            calendar.date(
                byAdding: unit.calendarComponent,
                value: offset,
                to: reference
            )
            .map { unit.normalized($0, calendar: calendar) }
        }
    }

    var body: some View {
        periodStrip
    }

    @ViewBuilder
    private var periodStrip: some View {
        if #available(iOS 18.0, *) {
            scrollView
                .onScrollPhaseChange { _, phase in
                    guard phase == .idle else { return }
                    commitPendingSelection()
                }
        } else {
            scrollView
                .simultaneousGesture(fallbackDragGesture)
        }
    }

    private var scrollView: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: spacing) {
                ForEach(dates, id: \.self) { date in
                    content(
                        date,
                        unit.contains(date, selectedDate: selectedDate, calendar: calendar)
                    )
                    .containerRelativeFrame(
                        .horizontal,
                        count: visibleItemCount,
                        span: 1,
                        spacing: spacing
                    )
                    .id(date)
                }
            }
            .scrollTargetLayout()
        }
        .frame(height: height)
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrollTarget, anchor: .center)
        .onAppear {
            scrollTarget = unit.normalized(selectedDate, calendar: calendar)
        }
        .onChange(of: selectedDate) { _, date in
            invalidatePendingSelection()
            let normalizedDate = unit.normalized(date, calendar: calendar)
            guard scrollTarget != normalizedDate else { return }
            scrollTarget = normalizedDate
        }
        .onChange(of: scrollTarget) { _, date in
            guard let date else { return }
            guard !unit.contains(date, selectedDate: selectedDate, calendar: calendar) else {
                pendingSelection = nil
                return
            }
            pendingSelection = date
            if #unavailable(iOS 18.0), !fallbackIsDragging {
                scheduleFallbackCommit()
            }
        }
    }

    private var fallbackDragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { _ in
                guard !fallbackIsDragging else { return }
                fallbackIsDragging = true
                fallbackCommitRevision += 1
            }
            .onEnded { _ in
                fallbackIsDragging = false
                scheduleFallbackCommit()
            }
    }

    private func scheduleFallbackCommit() {
        fallbackCommitRevision += 1
        let revision = fallbackCommitRevision

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(140))
            guard revision == fallbackCommitRevision, !fallbackIsDragging else { return }
            commitPendingSelection()
        }
    }

    private func commitPendingSelection() {
        guard let date = pendingSelection else { return }
        pendingSelection = nil
        guard !unit.contains(date, selectedDate: selectedDate, calendar: calendar) else {
            return
        }
        selectedDate = date
    }

    private func invalidatePendingSelection() {
        fallbackCommitRevision += 1
        pendingSelection = nil
    }
}
