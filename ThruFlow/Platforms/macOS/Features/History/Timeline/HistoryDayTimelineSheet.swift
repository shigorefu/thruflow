#if os(macOS)
import AppKit
import SwiftUI

struct HistoryDayTimelineSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    let date: Date
    let items: [HistoryCalendarItem]
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
                        items: items,
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
                Text(date.formatted(.dateTime.locale(locale).month().day().weekday(.wide)))
                    .font(.title3.weight(.semibold))
                Text(String(localized: "この日の記録"))
                    .font(.subheadline)
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
}

struct AnimatedSheetWindowSize: NSViewRepresentable {
    let size: CGSize

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.targetSize = size
        DispatchQueue.main.async {
            context.coordinator.captureInitialWindow(from: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard context.coordinator.targetSize != size else { return }

        let previousSize = context.coordinator.targetSize
        context.coordinator.targetSize = size

        DispatchQueue.main.async {
            context.coordinator.animateWindow(
                from: previousSize,
                to: size,
                attachedTo: nsView
            )
        }
    }

    final class Coordinator {
        var targetSize: CGSize = .zero
        private weak var window: NSWindow?

        func captureInitialWindow(from view: NSView) {
            window = view.window
        }

        func animateWindow(from previousSize: CGSize, to targetSize: CGSize, attachedTo view: NSView) {
            guard previousSize != .zero,
                  previousSize != targetSize,
                  let window = view.window ?? window else {
                self.window = view.window
                return
            }

            self.window = window
            let targetFrame = frame(for: targetSize, preservingTopOf: window.frame, in: window)
            let previousFrame = frame(for: previousSize, preservingTopOf: window.frame, in: window)

            window.setFrame(previousFrame, display: false)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.24
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(targetFrame, display: true)
            }
        }

        private func frame(for contentSize: CGSize, preservingTopOf currentFrame: NSRect, in window: NSWindow) -> NSRect {
            let contentRect = NSRect(origin: .zero, size: contentSize)
            let frameSize = window.frameRect(forContentRect: contentRect).size
            return NSRect(
                x: currentFrame.midX - (frameSize.width / 2),
                y: currentFrame.maxY - frameSize.height,
                width: frameSize.width,
                height: frameSize.height
            )
        }
    }
}
#endif
