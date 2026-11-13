//
//  HistoryDayWorkspaceView.swift
//  ThruFlow
//
//

import SwiftData
import SwiftUI

struct HistoryDayWorkspaceView: View {
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale

    @Binding var selectedDate: Date
    let items: [HistoryCalendarItem]
    @Binding var selectedItemID: String?
    @Binding var manualFlowDraft: HistoryFlowCreationDraft?
    @Binding var visibleKinds: Set<HistoryCalendarItemKind>
    let sidebarHeader: AnyView
    var historySessions: [FlowSession] = []
    var showsInspector = true
    let onEdit: (HistoryCalendarItem) -> Void
    let onMove: (HistoryCalendarItem, Date) -> Bool
    let onDropOnDay: (String, Date) -> Bool

    private var dayInterval: DateInterval {
        dayBoundary.interval(for: selectedDate, calendar: calendar)
    }

    private var selectedItem: HistoryCalendarItem? {
        guard let selectedItemID else { return nil }
        return items.first { $0.id == selectedItemID }
    }

    var body: some View {
        GeometryReader { geometry in
            if !showsInspector {
                timelinePanel
            } else if geometry.size.width >= 900 {
                HStack(spacing: 0) {
                    timelinePanel
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Divider()

                    HistoryDayInspectorPane(
                        selectedDate: $selectedDate,
                        selectedItem: selectedItem,
                        manualFlowDraft: $manualFlowDraft,
                        sidebarHeader: sidebarHeader,
                        historySessions: historySessions,
                        onEdit: onEdit,
                        onDropOnDay: onDropOnDay
                    )
                    .frame(width: min(390, max(310, geometry.size.width * 0.34)))
                }
            } else {
                timelinePanel
                    .sheet(
                        isPresented: Binding(
                            get: { manualFlowDraft != nil },
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
        }
        .onChange(of: selectedDate) { _, _ in
            selectedItemID = nil
            manualFlowDraft = nil
        }
    }

    private var timelinePanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedDate.formatted(.dateTime.locale(locale).month().day()))
                        .font(.headline)
                    Text(selectedDate.formatted(.dateTime.locale(locale).weekday(.wide)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            HistoryVerticalTimelineView(
                items: items,
                selectedItemID: selectedItemID,
                gapInterval: dayInterval
            ) { item in
                manualFlowDraft = nil
                selectedItemID = item.id
                onEdit(item)
            }
        }
    }

    private func updateManualFlowDraft(startedAt: Date, endedAt: Date) {
        manualFlowDraft?.startedAt = startedAt
        manualFlowDraft?.endedAt = endedAt
    }
}
