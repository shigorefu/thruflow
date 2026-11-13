//
//  HistoryCalendarView.swift
//  ThruFlow
//
//

import SwiftData
import SwiftUI

struct HistoryCalendarView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore

    @Binding var selectedDate: Date
    @Binding var range: HistoryCalendarRange

    let sessions: [FlowSession]
    let breaks: [FlowBreak]
    let hasLoaded: Bool
    let loadFailed: Bool
    let reportReveal: Int
    @Binding var visibleKinds: Set<HistoryCalendarItemKind>
    let sidebarTitle: String
    let sidebarHeader: AnyView
    let sidebarSummary: AnyView?
    let onAddRecord: (Date) -> Void

    @State private var inspectedItem: HistoryCalendarItem?
    @State private var editedBreak: FlowBreak?
    @State private var inspectedSeries: HistoryCalendarSeriesBlock?
    @State private var inspectedDay: HistoryDayTimelineSelection?
    @State private var selectedDayItemID: String?
    @State private var manualFlowDraft: HistoryFlowCreationDraft?

    private let builder = HistoryCalendarBuilder()
    private let historyEditor = FlowHistoryEditor()

    private var snapshot: HistoryCalendarSnapshot {
        let interval = range.interval(
            containing: selectedDate,
            calendar: calendar,
            dayBoundary: dayBoundary
        )
        return builder.build(
            interval: interval,
            sessions: sessions,
            breaks: breaks
        )
    }

    private var filteredItems: [HistoryCalendarItem] {
        snapshot.items.filter { visibleKinds.contains($0.kind) }
    }

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width >= 900 {
                HStack(spacing: 0) {
                    Group {
                        if hasLoaded {
                            widePrimaryContent
                                .id(range)
                                .transition(reduceMotion ? .identity : .opacity)
                        } else {
                            loadStatus
                        }
                    }
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: reportReveal)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Divider()

                    wideSidebarContent
                        .frame(
                            width: MacCalendarSidebarLayout.width(
                                for: sidebarTitle,
                                in: geometry.size.width,
                                preferredFraction: 0.30
                            )
                        )
                }
            } else {
                if hasLoaded {
                    compactContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 0) {
                        sidebarHeader
                        loadStatus
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .sheet(item: $inspectedItem) { item in
            if let session = item.session {
                FlowHistoryInspectorView(
                    session: session,
                    segment: item.flowSegment
                )
            }
        }
        .sheet(item: $editedBreak) { flowBreak in
            HistoryBreakEditorView(flowBreak: flowBreak)
                .environmentObject(activeFlowStore)
        }
        .sheet(item: $inspectedSeries) { block in
            HistorySeriesTimelineView(block: block)
                .environmentObject(activeFlowStore)
        }
        .sheet(item: $inspectedDay) { selection in
            HistoryDayTimelineSheet(
                date: selection.date,
                items: selection.items
            )
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

    @ViewBuilder
    private var loadStatus: some View {
        if loadFailed {
            ContentUnavailableView(
                String(localized: "データを読み込めませんでした。"),
                systemImage: "exclamationmark.circle"
            )
        } else {
            FeatureLoadingIndicator()
        }
    }

    @ViewBuilder
    private var widePrimaryContent: some View {
        switch range {
        case .day:
            HistoryDayWorkspaceView(
                selectedDate: $selectedDate,
                items: filteredItems,
                selectedItemID: $selectedDayItemID,
                manualFlowDraft: $manualFlowDraft,
                visibleKinds: $visibleKinds,
                sidebarHeader: sidebarHeader,
                historySessions: sessions,
                showsInspector: false,
                onEdit: openEditor,
                onMove: moveHistoryItem,
                onDropOnDay: moveHistoryPayload
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
                onSelectSeries: openSeries,
                onSelect: openEditor,
                onMove: moveHistoryItem,
                onAddRecord: onAddRecord
            )
        case .month:
            HistoryMonthGrid(
                selectedDate: $selectedDate,
                items: filteredItems,
                onSelect: openEditor,
                onShowDay: openDayTimeline,
                onMove: moveHistoryItem
            )
        }
    }

    @ViewBuilder
    private var wideSidebarContent: some View {
        switch range {
        case .day:
            historyPeriodSidebar(summary: sidebarSummary) {
                HistoryMiniCalendar(
                    selectedDate: $selectedDate,
                    historySessions: sessions,
                    onDropPayload: moveHistoryPayload
                )
            }
        case .week:
            historyPeriodSidebar {
                HistoryMiniCalendar(
                    selectedDate: $selectedDate,
                    selectionMode: .week,
                    historySessions: sessions,
                    onDropPayload: moveHistoryPayload
                )
            }
        case .month:
            historyPeriodSidebar {
                HistoryYearMonthPicker(selectedDate: $selectedDate)
            }
        }
    }

    @ViewBuilder
    private var compactContent: some View {
        switch range {
        case .day:
            HistoryDayWorkspaceView(
                selectedDate: $selectedDate,
                items: filteredItems,
                selectedItemID: $selectedDayItemID,
                manualFlowDraft: $manualFlowDraft,
                visibleKinds: $visibleKinds,
                sidebarHeader: sidebarHeader,
                historySessions: sessions,
                onEdit: openEditor,
                onMove: moveHistoryItem,
                onDropOnDay: moveHistoryPayload
            )
        case .week:
            HistoryCalendarPeriodWorkspace(sidebarHeader: sidebarHeader) {
                HistoryTimeGrid(
                    selectedDate: selectedDate,
                    range: range,
                    items: filteredItems,
                    hourRange: 0..<24,
                    hourHeight: 64,
                    selectedItemID: nil,
                    manualFlowDraft: $manualFlowDraft,
                    onSelectSeries: openSeries,
                    onSelect: openEditor,
                    onMove: moveHistoryItem,
                    onAddRecord: onAddRecord
                )
            } inspector: {
                HistoryMiniCalendar(
                    selectedDate: $selectedDate,
                    selectionMode: .week,
                    historySessions: sessions,
                    onDropPayload: moveHistoryPayload
                )
            }
        case .month:
            HistoryCalendarPeriodWorkspace(sidebarHeader: sidebarHeader) {
                HistoryMonthGrid(
                    selectedDate: $selectedDate,
                    items: filteredItems,
                    onSelect: openEditor,
                    onShowDay: openDayTimeline,
                    onMove: moveHistoryItem
                )
            } inspector: {
                HistoryYearMonthPicker(selectedDate: $selectedDate)
            }
        }
    }

    private func historyPeriodSidebar<Content: View>(
        summary: AnyView? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            sidebarHeader

            Divider()

            content()
                .padding(16)

            if let summary {
                Divider()
                summary
                    .padding(16)
            }

            Spacer(minLength: 0)
        }
        .background(Color.secondary.opacity(0.035))
    }

    private func openEditor(_ item: HistoryCalendarItem) {
        manualFlowDraft = nil
        switch item.kind {
        case .flow:
            guard let session = item.session,
                  activeFlowStore.activeSession?.id != session.id else { return }
            inspectedItem = item
        case .rest:
            editedBreak = item.flowBreak
        }
    }

    private func openSeries(_ block: HistoryCalendarSeriesBlock) {
        manualFlowDraft = nil
        inspectedSeries = block
    }

    private func openDayTimeline(_ date: Date) {
        manualFlowDraft = nil
        let day = calendar.startOfDay(for: date)
        selectedDate = day
        inspectedDay = HistoryDayTimelineSelection(
            date: day,
            items: filteredItems.filter {
                calendar.isDate($0.startedAt, inSameDayAs: day)
            }
        )
    }

    private func updateManualFlowDraft(startedAt: Date, endedAt: Date) {
        manualFlowDraft?.startedAt = startedAt
        manualFlowDraft?.endedAt = endedAt
    }

    private func moveHistoryPayload(_ payload: String, to day: Date) -> Bool {
        guard let item = historyItem(for: payload) else { return false }
        let components = calendar.dateComponents([.hour, .minute, .second], from: item.startedAt)
        guard let target = calendar.date(
            bySettingHour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: components.second ?? 0,
            of: day
        ) else { return false }
        return moveHistoryItem(item, target)
    }

    private func moveHistoryItem(_ item: HistoryCalendarItem, _ targetDate: Date) -> Bool {
        guard item.kind == .flow,
              let session = item.session,
              activeFlowStore.activeSession?.id != session.id else { return false }

        do {
            try historyEditor.move(
                session: session,
                itemStartedAt: item.startedAt,
                to: targetDate,
                modelContext: modelContext
            )
            try modelContext.save()
            selectedDate = calendar.startOfDay(for: targetDate)
            selectedDayItemID = item.id
            return true
        } catch {
            modelContext.rollback()
            PersistenceIssueCenter.shared.report(error, operation: .historyUpdate)
            return false
        }
    }

    private func historyItem(for payload: String) -> HistoryCalendarItem? {
        guard payload.hasPrefix("history-flow:") else { return nil }
        return filteredItems.first { "history-flow:\($0.id)" == payload }
    }
}

private struct HistoryDayTimelineSelection: Identifiable {
    let date: Date
    let items: [HistoryCalendarItem]

    var id: Date { date }
}
