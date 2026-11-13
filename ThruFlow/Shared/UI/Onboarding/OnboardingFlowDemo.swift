#if os(macOS) || os(iOS)
import Foundation
import SwiftUI

struct OnboardingFlowDemo: View {
    @ObservedObject var store: OnboardingStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: reduceMotion ? 0.5 : 1.0 / 20.0,
                paused: !store.demoState.isRunning
            )
        ) { timeline in
            let projection = store.demoState.projection(at: timeline.date)
            let task = store.demoTaskPresentation
            let tint = Color(hex: task.areaColorHex)

            VStack(spacing: 12) {
                FlowTimerPanelShell(
                    style: demoPanelStyle
                ) {
                    FlowTimerPresentation(
                        progress: projection.timerProgress,
                        tint: timerTint(for: projection, taskTint: tint),
                        eyebrow: timerEyebrow(for: projection),
                        timeText: timerText(for: projection),
                        footer: FlowMode.sprint.displayName
                    )
                    .dial(style: demoPanelStyle)
                } context: {
                    demoContextButton(projection: projection, task: task, tint: tint)
                } mode: {
                    FlowModeSelector(
                        selection: .constant(.sprint),
                        isSelectionEnabled: true,
                        helpPresentation: demoPanelStyle == .mobile ? .sheet : .popover
                    )
                    .frame(maxWidth: demoPanelStyle == .dashboard ? 280 : nil)
                } controls: {
                    demoControls(projection: projection, taskTint: tint)
                }
                .padding(.horizontal, demoPanelStyle == .mobile ? -12 : 0)
                .frame(
                    width: demoPanelStyle == .dashboard ? 320 : nil,
                    height: demoPanelStyle == .dashboard ? 410 : nil
                )
                .allowsHitTesting(false)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(demoAccessibilityLabel(for: projection))
                .accessibilityIdentifier("onboarding.demo.panel")

                Text(demoCaption(for: projection))
                    .font(.caption)
                    .foregroundStyle(Color.primary.opacity(0.72))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .task(id: demoTaskID) {
            guard case .running(_, let duration) = store.demoState else { return }
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            store.updateDemo()
        }
        .onDisappear {
            if store.demoState.isRunning {
                store.cancelDemo()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active, store.demoState.isRunning else { return }
            store.cancelDemo()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.demo.preview")
    }

    private var demoTaskID: Int {
        switch store.demoState {
        case .idle: 0
        case .running: 1
        case .completed: 2
        }
    }

    private var demoPanelStyle: FlowTimerPanelStyle {
#if os(macOS)
        .dashboard
#else
        .mobile
#endif
    }

    private func timerTint(
        for projection: OnboardingDemoProjection,
        taskTint: Color
    ) -> Color {
        guard projection.phase == .breakTime || projection.stage == .pressingBreak else {
            return taskTint
        }
#if os(macOS)
        return projection.stage == .pressingBreak ? .blue : Color.secondary.opacity(0.72)
#else
        return projection.stage == .pressingBreak ? taskTint : .secondary
#endif
    }

    private func timerEyebrow(for projection: OnboardingDemoProjection) -> String {
        switch projection.phase {
        case .idle:
#if os(macOS)
            String(localized: "待機中")
#else
            projection.contextIsSelected
                ? String(localized: "準備完了")
                : String(localized: "未設定")
#endif
        case .focusing:
            String(localized: "集中")
        case .breakTime:
            String(localized: "休憩")
        }
    }

    private func timerText(for projection: OnboardingDemoProjection) -> String {
        String(
            format: "%02d:%02d",
            projection.remainingSeconds / 60,
            projection.remainingSeconds % 60
        )
    }

    @ViewBuilder
    private func demoContextButton(
        projection: OnboardingDemoProjection,
        task: OnboardingTaskPresentation,
        tint: Color
    ) -> some View {
        let isSelected = projection.contextIsSelected
        let title = isSelected
            ? task.title
            : demoPanelStyle == .mobile
                ? String(localized: "タスクを選択")
                : String(localized: "具体的なタスクなし")
        let area = isSelected
            ? task.areaName
            : demoPanelStyle == .mobile
                ? String(localized: "分野")
                : String(localized: "その他")
        let symbol = isSelected
            ? task.areaSymbol
            : demoPanelStyle == .mobile ? "🎯" : "▶"

        FlowTimerContextButton(
            style: demoPanelStyle,
            presentation: FlowTimerContextPresentation(
                symbol: symbol,
                areaTitle: area,
                tint: isSelected ? tint : .accentColor,
                isPlaceholder: !isSelected,
                showsProgress: isSelected
            ),
            isVisuallyPressed: !reduceMotion && projection.contextIsPressed,
            animatesVisualPress: true,
            accessibilityLabel: String(localized: "Flowタスクを選択"),
            action: {}
        ) {
            Text(title)
                .contentTransition(.opacity)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 0.16),
                    value: title
                )
        } progress: {
            OnboardingDemoCheckbox(tint: tint)
        }
    }

    private func demoControls(
        projection: OnboardingDemoProjection,
        taskTint: Color
    ) -> some View {
        let isBreak = projection.phase == .breakTime
        let primarySymbol: String = {
            switch projection.stage {
            case .focusing:
                return "pause.fill"
            case .pressingBreak:
                return "cup.and.saucer.fill"
            case .breakTime:
                return demoPanelStyle == .mobile ? "forward.fill" : "play.fill"
            default:
                return "play.fill"
            }
        }()
        let primaryTint: Color = {
            if projection.stage == .pressingBreak {
                return taskTint
            }
            if isBreak {
                return demoPanelStyle == .mobile ? .secondary : .blue
            }
            return taskTint
        }()

        return FlowTimerTransportControls(
            style: demoPanelStyle,
            presentation: FlowTimerTransportPresentation(
                primarySymbol: primarySymbol,
                primaryLabel: projection.stage == .pressingBreak
                    ? String(localized: "休憩")
                    : isBreak
                        ? String(localized: "Flowを開始")
                        : String(localized: "一時停止"),
                primaryTint: primaryTint,
                isPrimaryEnabled: projection.contextIsSelected,
                canSeek: projection.canSeek,
                canDestroy: projection.hasActiveTimer,
                canStop: projection.hasActiveTimer,
                canStartBreak: projection.canStartBreak,
                destroyLabel: isBreak ? String(localized: "休憩を削除") : String(localized: "Flowを破壊"),
                visuallyPressedAction: reduceMotion
                    ? nil
                    : projection.primaryIsPressed
                        ? .primary
                        : nil
            ),
            animatesVisualPress: true,
            action: { _ in }
        )
    }

    private func demoCaption(for projection: OnboardingDemoProjection) -> String {
        switch projection.stage {
        case .awaitingTask, .pressingContext:
            String(localized: "タスクを選択")
        case .ready, .pressingPlay:
            String(localized: "Flowを開始")
        case .focusing:
            String(localized: "12分の集中を早送り中")
        case .pressingBreak:
            String(localized: "休憩を開始")
        case .breakTime:
            String(localized: "3分の休憩に切り替わりました")
        }
    }

    private func demoAccessibilityLabel(for projection: OnboardingDemoProjection) -> String {
        switch projection.stage {
        case .awaitingTask, .pressingContext:
            String(localized: "タスクを選択")
        case .ready, .pressingPlay:
            String(localized: "Flowを開始")
        case .focusing:
            String(localized: "12分の集中を早送り中")
        case .pressingBreak:
            String(localized: "休憩を開始")
        case .breakTime:
            String(localized: "3分の休憩")
        }
    }
}

private struct OnboardingDemoCheckbox: View {
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 5)
            .strokeBorder(tint, lineWidth: 1.6)
            .frame(width: 20, height: 20)
            .frame(width: 34, height: 34)
            .accessibilityHidden(true)
    }
}

#endif
