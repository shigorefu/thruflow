//
//  HistoryCalendarView.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/14.
//

import SwiftData
import SwiftUI

struct HistoryCalendarView: View {
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    @Binding var selectedDate: Date
    @Binding var range: HistoryCalendarRange

    let sessions: [FlowSession]
    let breaks: [FlowBreak]

    @State private var visibleKinds = Set(HistoryCalendarItemKind.allCases)
    @State private var inspectedSession: FlowSession?
    @State private var editedBreak: FlowBreak?
    @State private var selectedDayItemID: String?
    @State private var manualFlowDraft: HistoryFlowCreationDraft?
    @AppStorage("history.dayTimelineScale") private var dayScaleRawValue = HistoryDayTimelineScale.elastic.rawValue

    private let calendar = Calendar.current
    private let builder = HistoryCalendarBuilder()

    private var snapshot: HistoryCalendarSnapshot {
        let interval = range.interval(containing: selectedDate, calendar: calendar)
        return builder.build(
            interval: interval,
            sessions: sessions,
            breaks: breaks
        )
    }

    private var filteredItems: [HistoryCalendarItem] {
        snapshot.items.filter { visibleKinds.contains($0.kind) }
    }

    private var dayScaleBinding: Binding<HistoryDayTimelineScale> {
        Binding(
            get: { HistoryDayTimelineScale(rawValue: dayScaleRawValue) ?? .elastic },
            set: { dayScaleRawValue = $0.rawValue }
        )
    }

    var body: some View {
        VStack(spacing: 8) {
            if range != .day {
                HStack {
                    Spacer()
                    HistoryVisibilityMenu(visibleKinds: $visibleKinds)
                }
                .padding(.horizontal, 10)
            }

            Group {
                switch range {
                case .day:
                    HistoryDayWorkspaceView(
                        selectedDate: $selectedDate,
                        scale: dayScaleBinding,
                        items: filteredItems,
                        selectedItemID: $selectedDayItemID,
                        manualFlowDraft: $manualFlowDraft,
                        visibleKinds: $visibleKinds,
                        onEdit: openEditor
                    )
                case .week:
                    HistoryTimeGrid(
                        selectedDate: selectedDate,
                        range: range,
                        items: filteredItems,
                        hourRange: 0..<24,
                        hourHeight: 64,
                        selectedItemID: nil,
                        manualFlowDraft: $manualFlowDraft,
                        onSelect: openEditor
                    )
                case .month:
                    HistoryMonthGrid(
                        selectedDate: $selectedDate,
                        items: filteredItems,
                        onSelect: openEditor
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(item: $inspectedSession) { session in
            FlowHistoryInspectorView(session: session)
        }
        .sheet(item: $editedBreak) { flowBreak in
            HistoryBreakEditorView(flowBreak: flowBreak)
                .environmentObject(activeFlowStore)
        }
        .sheet(
            isPresented: Binding(
                get: { range == .week && manualFlowDraft != nil },
                set: { if !$0 { manualFlowDraft = nil } }
            )
        ) {
            if let draft = manualFlowDraft {
                ManualFlowCreationView(
                    startedAt: draft.startedAt,
                    onTimeChange: updateManualFlowDraft
                ) {
                    manualFlowDraft = nil
                }
                .id(draft.id)
            }
        }
    }

    private func openEditor(_ item: HistoryCalendarItem) {
        manualFlowDraft = nil
        switch item.kind {
        case .flow:
            guard let session = item.session,
                  activeFlowStore.activeSession?.id != session.id else { return }
            inspectedSession = session
        case .rest:
            editedBreak = item.flowBreak
        }
    }

    private func updateManualFlowDraft(startedAt: Date, endedAt: Date) {
        manualFlowDraft?.startedAt = startedAt
        manualFlowDraft?.endedAt = endedAt
    }
}

struct HistoryVisibilityMenu: View {
    @Binding var visibleKinds: Set<HistoryCalendarItemKind>

    var body: some View {
        Menu {
            filterToggle("Flow", symbol: "waveform.path", kinds: [.flow])
            filterToggle("休憩", symbol: "cup.and.saucer", kinds: [.rest])
        } label: {
            Label("表示", systemImage: "line.3.horizontal.decrease.circle")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel("表示内容")
    }

    private func filterToggle(_ title: String, symbol: String, kinds: Set<HistoryCalendarItemKind>) -> some View {
        Toggle(isOn: Binding(
            get: { kinds.isSubset(of: visibleKinds) },
            set: { isVisible in
                if isVisible { visibleKinds.formUnion(kinds) } else { visibleKinds.subtract(kinds) }
            }
        )) {
            Label(title, systemImage: symbol)
        }
        .toggleStyle(.checkbox)
    }

}

struct HistoryTimeGrid: View {
    let selectedDate: Date
    let range: HistoryCalendarRange
    let items: [HistoryCalendarItem]
    let hourRange: Range<Int>
    let hourHeight: CGFloat
    let selectedItemID: String?
    @Binding var manualFlowDraft: HistoryFlowCreationDraft?
    let onSelect: (HistoryCalendarItem) -> Void

    private let calendar = Calendar.current
    private let timeAxisWidth: CGFloat = 72
    private let minimumDayWidth: CGFloat = 132
    private let minimumItemHeight: CGFloat = 18

    private var days: [Date] {
        let interval = range.interval(containing: selectedDate, calendar: calendar)
        let count = range == .day ? 1 : 7
        return (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }

    var body: some View {
        GeometryReader { geometry in
            let available = max(0, geometry.size.width - timeAxisWidth)
            let dayWidth = range == .day
                ? max(minimumDayWidth, available)
                : max(minimumDayWidth, available / CGFloat(days.count))
            let contentWidth = timeAxisWidth + dayWidth * CGFloat(days.count)

            ScrollView(.horizontal) {
                VStack(spacing: 0) {
                    dayHeader(dayWidth: dayWidth)
                    Divider()
                    hourScroll(dayWidth: dayWidth, contentWidth: contentWidth)
                }
                .frame(width: contentWidth)
            }
            .scrollIndicators(.automatic)
        }
    }

    private func dayHeader(dayWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: timeAxisWidth, height: 54)
            ForEach(days, id: \.self) { day in
                VStack(spacing: 3) {
                    Text(day.formatted(.dateTime.locale(Locale(identifier: "ja_JP")).weekday(.abbreviated)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(calendar.component(.day, from: day))")
                        .font(.title3.weight(calendar.isDateInToday(day) ? .bold : .medium))
                        .foregroundStyle(calendar.isDateInToday(day) ? Color.accentColor : Color.primary)
                }
                .frame(width: dayWidth, height: 54)
                .background(calendar.isDate(day, inSameDayAs: selectedDate) ? Color.accentColor.opacity(0.045) : .clear)
                .overlay(alignment: .leading) { Divider() }
            }
        }
    }

    private func hourScroll(dayWidth: CGFloat, contentWidth: CGFloat) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                ZStack(alignment: .topLeading) {
                    hourGrid(dayWidth: dayWidth, contentWidth: contentWidth)
                        .allowsHitTesting(false)
                    emptyDoubleClickLayer(dayWidth: dayWidth)
                    timedItems(dayWidth: dayWidth)
                    manualFlowDraftBlock(dayWidth: dayWidth)
                    currentTimeLine(dayWidth: dayWidth)
                }
                .frame(width: contentWidth, height: hourHeight * CGFloat(hourRange.count))
            }
            .onAppear { scrollToRelevantHour(proxy) }
            .onChange(of: selectedDate) { _, _ in scrollToRelevantHour(proxy) }
            .onChange(of: range) { _, _ in scrollToRelevantHour(proxy) }
        }
    }

    private func hourGrid(dayWidth: CGFloat, contentWidth: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ForEach(Array(hourRange), id: \.self) { hour in
                    HStack(alignment: .top, spacing: 8) {
                        Text(String(format: "%d:00", hour))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: timeAxisWidth - 8, alignment: .trailing)
                            .offset(y: -7)
                        Rectangle()
                            .fill(Color.secondary.opacity(hour == 0 ? 0.22 : 0.13))
                            .frame(height: 1)
                    }
                    .frame(width: contentWidth, height: hourHeight, alignment: .topLeading)
                    .id("history-hour-\(hour)")
                }

                HStack(spacing: 8) {
                    Color.clear.frame(width: timeAxisWidth - 8)
                    Rectangle().fill(Color.secondary.opacity(0.13)).frame(height: 1)
                }
                .frame(width: contentWidth, alignment: .leading)
            }

            ForEach(0...days.count, id: \.self) { index in
                Rectangle()
                    .fill(Color.secondary.opacity(0.12))
                    .frame(width: 1, height: hourHeight * CGFloat(hourRange.count))
                    .offset(x: timeAxisWidth + CGFloat(index) * dayWidth)
            }
        }
    }

    @ViewBuilder
    private func timedItems(dayWidth: CGFloat) -> some View {
        ForEach(Array(days.enumerated()), id: \.offset) { dayIndex, day in
            let dayItems = timedItems(on: day)
            let placements = placementMap(for: dayItems, day: day)

            ForEach(dayItems) { item in
                let placement = placements[item.id] ?? HistoryOverlapPlacement(id: item.id, lane: 0, laneCount: 1)
                let width = (dayWidth - 8) / CGFloat(placement.laneCount)
                let frame = frame(for: item, on: day)

                HistoryTimedItemView(
                    item: item,
                    isCompact: item.durationSeconds < 15 * 60,
                    isSelected: selectedItemID == item.id
                ) {
                    manualFlowDraft = nil
                    onSelect(item)
                }
                    .frame(width: max(32, width - 3), height: frame.height, alignment: .topLeading)
                    .offset(
                        x: timeAxisWidth + CGFloat(dayIndex) * dayWidth + 4 + CGFloat(placement.lane) * width,
                        y: frame.y
                    )
            }
        }
    }

    @ViewBuilder
    private func emptyDoubleClickLayer(dayWidth: CGFloat) -> some View {
        let height = hourHeight * CGFloat(hourRange.count)
        ForEach(Array(days.enumerated()), id: \.offset) { dayIndex, day in
            Color.clear
                .contentShape(Rectangle())
                .frame(width: dayWidth, height: height)
                .offset(x: timeAxisWidth + CGFloat(dayIndex) * dayWidth)
                .gesture(
                    SpatialTapGesture(count: 2)
                        .onEnded { value in
                            let y = min(max(0, value.location.y), height)
                            let startedAt = date(on: day, y: y)
                            manualFlowDraft = HistoryFlowCreationDraft(
                                startedAt: startedAt,
                                endedAt: startedAt.addingTimeInterval(25 * 60)
                            )
                        }
                )
        }
    }

    @ViewBuilder
    private func manualFlowDraftBlock(dayWidth: CGFloat) -> some View {
        if let draft = manualFlowDraft,
           let dayIndex = days.firstIndex(where: { calendar.isDate($0, inSameDayAs: draft.startedAt) }) {
            let day = days[dayIndex]
            let interval = visibleInterval(on: day)
            let start = max(draft.startedAt, interval.start)
            let end = min(draft.endedAt, interval.end)

            if end > start {
                let y = CGFloat(start.timeIntervalSince(interval.start) / 3600) * hourHeight
                let height = max(minimumItemHeight, CGFloat(end.timeIntervalSince(start) / 3600) * hourHeight)

                HistoryManualFlowDraftView(startedAt: draft.startedAt, endedAt: draft.endedAt)
                    .frame(width: dayWidth - 8, height: height, alignment: .topLeading)
                    .offset(x: timeAxisWidth + CGFloat(dayIndex) * dayWidth + 4, y: y)
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private func currentTimeLine(dayWidth: CGFloat) -> some View {
        let currentHour = calendar.component(.hour, from: .now)
        if let todayIndex = days.firstIndex(where: calendar.isDateInToday),
           hourRange.contains(currentHour) {
            let components = calendar.dateComponents([.hour, .minute, .second], from: .now)
            let hourSeconds = (components.hour ?? 0) * 3600
            let minuteSeconds = (components.minute ?? 0) * 60
            let seconds = CGFloat(hourSeconds + minuteSeconds + (components.second ?? 0))
            let y = (seconds / 3600 - CGFloat(hourRange.lowerBound)) * hourHeight
            HStack(spacing: 0) {
                Circle().fill(Color.red).frame(width: 7, height: 7)
                Rectangle().fill(Color.red).frame(height: 1)
            }
            .frame(width: dayWidth)
            .offset(x: timeAxisWidth + CGFloat(todayIndex) * dayWidth - 3, y: y - 3)
            .allowsHitTesting(false)
        }
    }

    private func timedItems(on day: Date) -> [HistoryCalendarItem] {
        let dayStart = calendar.startOfDay(for: day)
        let start = calendar.date(byAdding: .hour, value: hourRange.lowerBound, to: dayStart)!
        let end = calendar.date(byAdding: .hour, value: hourRange.upperBound, to: dayStart)!
        return items.filter { $0.startedAt < end && $0.endedAt > start }
    }

    private func placementMap(for items: [HistoryCalendarItem], day: Date) -> [String: HistoryOverlapPlacement] {
        let interval = visibleInterval(on: day)
        let inputs = items.map {
            HistoryOverlapInput(id: $0.id, start: max($0.startedAt, interval.start), end: min($0.endedAt, interval.end))
        }
        let minimumDuration = TimeInterval(minimumItemHeight / hourHeight * 3600)
        let placements = HistoryOverlapLayout().place(inputs, minimumDuration: minimumDuration)
        return Dictionary(uniqueKeysWithValues: placements.map { ($0.id, $0) })
    }

    private func frame(for item: HistoryCalendarItem, on day: Date) -> (y: CGFloat, height: CGFloat) {
        let interval = visibleInterval(on: day)
        let start = max(item.startedAt, interval.start)
        let end = min(item.endedAt, interval.end)
        let startSeconds = max(0, start.timeIntervalSince(interval.start))
        let duration = max(0, end.timeIntervalSince(start))
        return (
            CGFloat(startSeconds / 3600) * hourHeight,
            max(minimumItemHeight, CGFloat(duration / 3600) * hourHeight)
        )
    }

    private func visibleInterval(on day: Date) -> DateInterval {
        let dayStart = calendar.startOfDay(for: day)
        return DateInterval(
            start: calendar.date(byAdding: .hour, value: hourRange.lowerBound, to: dayStart)!,
            end: calendar.date(byAdding: .hour, value: hourRange.upperBound, to: dayStart)!
        )
    }

    private func date(on day: Date, y: CGFloat) -> Date {
        let interval = visibleInterval(on: day)
        let rawSeconds = TimeInterval(y / hourHeight * 3600)
        let roundedSeconds = (rawSeconds / 300).rounded() * 300
        return min(interval.end.addingTimeInterval(-60), interval.start.addingTimeInterval(roundedSeconds))
    }

    private func scrollToRelevantHour(_ proxy: ScrollViewProxy) {
        let timed = items.filter { item in
            days.contains { day in
                calendar.isDate(item.startedAt, inSameDayAs: day)
            }
        }
        let targetDate: Date
        if days.contains(where: calendar.isDateInToday) {
            targetDate = .now
        } else {
            targetDate = timed.map(\.startedAt).min() ?? selectedDate.addingTimeInterval(8 * 3600)
        }
        let hour = min(hourRange.upperBound - 1, max(hourRange.lowerBound, calendar.component(.hour, from: targetDate) - 1))
        DispatchQueue.main.async {
            proxy.scrollTo("history-hour-\(hour)", anchor: .top)
        }
    }
}

struct HistoryFlowCreationDraft: Identifiable {
    let id = UUID()
    var startedAt: Date
    var endedAt: Date
}

private struct HistoryManualFlowDraftView: View {
    let startedAt: Date
    let endedAt: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("新しいFlow")
                .font(.caption.weight(.semibold))
            Text("\(startedAt.formatted(date: .omitted, time: .shortened))–\(endedAt.formatted(date: .omitted, time: .shortened))")
                .font(.caption2.monospacedDigit())
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.white.opacity(0.75), lineWidth: 1.5)
        }
        .accessibilityLabel("新しいFlow、\(startedAt.formatted(date: .omitted, time: .shortened))から\(endedAt.formatted(date: .omitted, time: .shortened))")
    }
}

private struct HistoryTimedItemView: View {
    let item: HistoryCalendarItem
    let isCompact: Bool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isCompact {
                    HStack(spacing: 4) {
                        Text(item.symbol)
                        Text(item.title)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    }
                    .font(.caption2)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(item.symbol)
                            Text(item.title)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                        }
                        Text(timeText)
                            .font(.caption2.monospacedDigit())
                            .lineLimit(1)
                        if item.durationSeconds >= 35 * 60 {
                            Text(item.subtitle)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                    }
                    .font(.caption)
                }
            }
            .foregroundStyle(item.kind == .rest ? Color.primary : Color.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, isCompact ? 4 : 5)
            .padding(.vertical, isCompact ? 2 : 5)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(isSelected ? Color.accentColor : borderColor, lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .help("\(item.title)\n\(timeText)\n\(item.subtitle)")
        .accessibilityLabel("\(item.title)、\(timeText)、\(item.subtitle)")
    }

    private var background: Color {
        if item.kind == .rest { return Color.secondary.opacity(0.15) }
        return Color(hex: item.colorHex).opacity(0.9)
    }

    private var borderColor: Color {
        item.kind == .rest ? Color.secondary.opacity(0.35) : Color(hex: item.colorHex)
    }

    private var timeText: String {
        "\(item.startedAt.formatted(date: .omitted, time: .shortened))–\(item.endedAt.formatted(date: .omitted, time: .shortened))"
    }
}

private struct HistoryMonthGrid: View {
    @Binding var selectedDate: Date
    let items: [HistoryCalendarItem]
    let onSelect: (HistoryCalendarItem) -> Void

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    private var days: [Date] {
        guard let month = calendar.dateInterval(of: .month, for: selectedDate),
              let firstWeek = calendar.dateInterval(of: .weekOfYear, for: month.start) else { return [] }
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: firstWeek.start) }
    }

    var body: some View {
        GeometryReader { geometry in
            let contentWidth = max(700, geometry.size.width)
            ScrollView(.horizontal) {
                VStack(spacing: 0) {
                    LazyVGrid(columns: columns, spacing: 0) {
                        ForEach(weekdaySymbols, id: \.self) { symbol in
                            Text(symbol)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                    }

                    GeometryReader { monthGeometry in
                        let cellHeight = max(76, monthGeometry.size.height / 6)
                        ScrollView(.vertical) {
                            LazyVGrid(columns: columns, spacing: 0) {
                                ForEach(days, id: \.self) { day in
                                    monthCell(day, height: cellHeight)
                                }
                            }
                        }
                    }
                }
                .frame(width: contentWidth, height: geometry.size.height)
            }
            .scrollIndicators(.automatic)
        }
    }

    private func monthCell(_ day: Date, height: CGFloat) -> some View {
        let dayItems = items.filter {
            calendar.isDate($0.startedAt, inSameDayAs: day)
        }
        return VStack(alignment: .leading, spacing: 3) {
            Button {
                selectedDate = calendar.startOfDay(for: day)
            } label: {
                Text("\(calendar.component(.day, from: day))")
                    .font(.callout.weight(calendar.isDateInToday(day) ? .bold : .regular))
                    .foregroundStyle(calendar.isDateInToday(day) ? Color.white : dayTextColor(day))
                    .frame(width: 25, height: 25)
                    .background(calendar.isDateInToday(day) ? Color.accentColor : Color.clear)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            ForEach(dayItems.prefix(3)) { item in
                Button { onSelect(item) } label: {
                    HStack(spacing: 3) {
                        Circle().fill(item.kind == .rest ? Color.secondary : Color(hex: item.colorHex)).frame(width: 5, height: 5)
                        Text(item.title).lineLimit(1)
                    }
                    .font(.caption2)
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            }

            if dayItems.count > 3 {
                Text("ほか\(dayItems.count - 3)件")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(6)
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
        .background(calendar.isDate(day, inSameDayAs: selectedDate) ? Color.accentColor.opacity(0.05) : .clear)
        .overlay { Rectangle().stroke(Color.secondary.opacity(0.13), lineWidth: 0.5) }
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let offset = max(0, calendar.firstWeekday - 1)
        return Array(symbols[offset...]) + Array(symbols[..<offset])
    }

    private func dayTextColor(_ day: Date) -> Color {
        calendar.isDate(day, equalTo: selectedDate, toGranularity: .month) ? .primary : .secondary
    }
}

private struct HistoryBreakEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    let flowBreak: FlowBreak
    @State private var minutes: Int
    @State private var errorMessage: String?

    private let editor = FlowBreakEditor()

    init(flowBreak: FlowBreak) {
        self.flowBreak = flowBreak
        let duration = flowBreak.resolvedEndAt(referenceDate: .now).timeIntervalSince(flowBreak.startedAt)
        _minutes = State(initialValue: max(1, Int(ceil(duration / 60))))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Label(flowBreak.isLongBreak ? "Long Break" : "休憩", systemImage: "cup.and.saucer")
                        .font(.title3.weight(.semibold))
                    Text("開始 \(flowBreak.startedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark") }
                    .buttonStyle(.borderless)
            }

            HStack {
                Text("時間")
                Spacer()
                TextField("分", value: $minutes, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 76)
                    .multilineTextAlignment(.trailing)
                Text("分")
                    .foregroundStyle(.secondary)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("キャンセル") { dismiss() }
                Spacer()
                Button("保存") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(minutes < FlowBreakEditor.minimumDurationMinutes || minutes > FlowBreakEditor.maximumDurationMinutes)
            }
        }
        .padding(20)
        .frame(width: 360)
    }

    private func save() {
        do {
            _ = try editor.updateDuration(
                of: flowBreak,
                minutes: minutes,
                modelContext: modelContext,
                protectedSessionID: activeFlowStore.activeSession?.id
            )
            dismiss()
        } catch FlowBreakEditorError.activeFlowWouldMove {
            errorMessage = "実行中のFlowは移動できません。"
        } catch {
            errorMessage = "休憩を保存できませんでした。"
        }
    }
}
