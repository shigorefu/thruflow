#if os(macOS)
//
//  HistorySeriesTimelineView.swift
//  ThruFlow
//
//

import AppKit
import SwiftUI

struct HistorySeriesTimelineView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    let block: HistoryCalendarSeriesBlock
    @State private var selectedItem: HistoryCalendarItem?

    var body: some View {
        ZStack {
            if let selectedItem {
                HistoryRecordEditorView(item: selectedItem) {
                    withAnimation(.easeInOut(duration: 0.24)) {
                        self.selectedItem = nil
                    }
                }
                .transition(.move(edge: .trailing))
            } else {
                VStack(spacing: 0) {
                    header
                    Divider()

                    HistoryVerticalTimelineView(
                        items: block.items,
                        selectedItemID: nil,
                        gapInterval: nil
                    ) { item in
                        withAnimation(.easeInOut(duration: 0.24)) {
                            selectedItem = item
                        }
                    }
                }
                .transition(.move(edge: .leading))
            }
        }
        .clipped()
        .frame(width: contentSize.width, height: contentSize.height)
        .background {
            AnimatedSheetWindowSize(size: contentSize)
        }
    }

    private var contentSize: CGSize {
        guard let selectedItem else {
            return CGSize(width: 500, height: 620)
        }

        switch selectedItem.kind {
        case .flow:
            return CGSize(width: 540, height: 580)
        case .rest:
            return CGSize(width: 360, height: 280)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(String(localized: "一連の集中記録"))
                    .font(.title3.weight(.semibold))
                Text(seriesIntervalText)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(String(localized: "閉じる"))
        }
        .padding(20)
    }

    private var seriesIntervalText: String {
        let date = block.startedAt.formatted(.dateTime.locale(locale).month().day().weekday(.abbreviated))
        let time = "\(block.startedAt.formatted(date: .omitted, time: .shortened))–\(block.endedAt.formatted(date: .omitted, time: .shortened))"
        return String(localized: "\(date) · \(time)")
    }
}

#endif
