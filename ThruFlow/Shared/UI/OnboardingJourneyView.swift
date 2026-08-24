import Foundation
import SwiftUI

extension View {
    func onboardingJourney(store: OnboardingStore) -> some View {
        modifier(OnboardingJourneyModifier(store: store))
    }
}

private struct OnboardingJourneyModifier: ViewModifier {
    @ObservedObject var store: OnboardingStore

    func body(content: Content) -> some View {
        content
            .allowsHitTesting(!store.isPresented)
            .accessibilityHidden(store.isPresented)
            .overlay {
                if store.isPresented {
                    OnboardingJourneyOverlay(store: store)
                        .ignoresSafeArea()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.24), value: store.isPresented)
    }
}

private struct OnboardingJourneyOverlay: View {
    @ObservedObject var store: OnboardingStore

    var body: some View {
        GeometryReader { proxy in
            let cardWidth = min(520, max(288, proxy.size.width - 32))

            ZStack {
                Color.black.opacity(0.64)
                    .contentShape(Rectangle())

                ScrollView {
                    OnboardingJourneyCard(store: store)
                        .frame(width: cardWidth)
                        .frame(maxWidth: .infinity)
                        .padding(.top, max(16, proxy.safeAreaInsets.top + 8))
                        .padding(.bottom, max(16, proxy.safeAreaInsets.bottom + 8))
                        .frame(minHeight: proxy.size.height, alignment: .center)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .animation(.snappy(duration: 0.28, extraBounce: 0), value: store.step)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.journey")
    }
}

private struct OnboardingJourneyCard: View {
    @ObservedObject var store: OnboardingStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            VStack(alignment: .leading, spacing: 8) {
                Text(store.step.title)
                    .font(.title2.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)

                Text(store.step.body)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            stepContent

            navigationControls
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16))
        }
        .shadow(color: .black.opacity(0.3), radius: 26, y: 10)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.card.step.\(store.step.rawValue)")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                pageIndicator

                HStack {
                    Spacer()

                    Button {
                        store.skip()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .frame(width: 28, height: 28)
                            .background(Color.primary.opacity(0.07), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .contentShape(Circle())
                    .accessibilityLabel(String(localized: "スキップ"))
                    .accessibilityIdentifier("onboarding.skip")
                }
            }

            Label {
                Text(store.step.eyebrow)
            } icon: {
                OnboardingIconView(icon: store.step.icon, width: 18)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.tint)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch store.step {
        case .welcome:
            OnboardingCallout(
                title: String(localized: "ひとつずつ試せます"),
                body: String(localized: "まず分野とタスクを作り、集中を始めるまでを短いデモで見てみましょう。途中でいつでもスキップできます。"),
                systemImage: "sparkles"
            )

        case .areas:
            VStack(spacing: 8) {
                OnboardingHintRow(
                    title: String(localized: "いつでも"),
                    body: String(localized: "必要なときに、自分でタスクを追加します。"),
                    systemImage: "calendar"
                )
                OnboardingHintRow(
                    title: String(localized: "習慣"),
                    body: String(localized: "設定した曜日や回数に合わせて、タスクが自動で追加されます。"),
                    systemImage: "repeat"
                )
                OnboardingHintRow(
                    title: String(localized: "できたら"),
                    body: String(localized: "時間に余裕があるときに取り組みたいこと向けです。"),
                    systemImage: "sparkles"
                )
            }

            if store.canOfferAreaCreation {
                OnboardingCallout(
                    title: String(localized: "最初の分野を作りましょう"),
                    body: String(localized: "「仕事」を用意しました。名前、絵文字、色は自由に変えられます。保存すると実際の分野として残ります。"),
                    systemImage: ProductSymbol.area
                )
            }

        case .tasks:
            VStack(spacing: 8) {
                OnboardingHintRow(
                    title: String(localized: "チェック"),
                    body: String(localized: "終わったら、自分で完了にします。"),
                    systemImage: "checkmark.circle"
                )
                OnboardingHintRow(
                    title: String(localized: "集中ブロック"),
                    body: String(localized: "25分を1ブロックとして、集中した時間が自動で進捗になります。"),
                    systemImage: "square.grid.3x3"
                )
                OnboardingHintRow(
                    title: String(localized: "分単位"),
                    body: String(localized: "集中した実時間を、分単位で積み上げます。"),
                    systemImage: "clock"
                )
            }

            OnboardingCallout(
                title: String(localized: "分野・優先度・日付"),
                body: String(localized: "タスクの分野、表示順、取り組む日を設定できます。「いつでも」の分野にある未完了タスクは、日付を過ぎると「やり残し」にまとまります。"),
                systemImage: "slider.horizontal.3"
            )

            if store.canOfferTaskCreation {
                OnboardingCallout(
                    title: String(localized: "最初のタスクを作りましょう"),
                    body: String(localized: "「レポートを仕上げる」を用意しました。内容と設定は自由に変えられます。保存すると今日の実際のタスクになります。"),
                    systemImage: "checklist"
                )
            }

        case .flow:
            VStack(spacing: 8) {
                OnboardingHintRow(
                    title: String(localized: "流れ"),
                    body: String(localized: "集中と休憩の積み重なりを映します。下のタイムラインでは、いつ・何に取り組んだかを確認できます。"),
                    icon: .flow
                )
                OnboardingHintRow(
                    title: String(localized: "今日のタスク"),
                    body: String(localized: "今日やることと、その進捗をすぐに確認できます。"),
                    systemImage: "checklist"
                )
                OnboardingHintRow(
                    title: String(localized: "今日の統計"),
                    body: String(localized: "集中時間と完了したタスクを、その場で振り返れます。"),
                    systemImage: "chart.bar.xaxis"
                )
            }

        case .timer:
            OnboardingHintRow(
                title: String(localized: "取り組むタスク"),
                body: String(localized: "タスクを選ぶと、集中時間がそのタスクと分野の進捗に反映されます。"),
                systemImage: "checklist"
            )

            OnboardingModeSummary()

        case .demo:
            OnboardingFlowDemo(store: store)

            if !store.demoState.isCompleted {
                Button(String(localized: "プレビューをスキップ")) {
                    store.advance()
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityIdentifier("onboarding.demo.skip.step.\(store.step.rawValue)")
            }

        case .history:
            VStack(spacing: 8) {
                OnboardingHintRow(
                    title: String(localized: "自動で記録"),
                    body: String(localized: "実際に行った集中、休憩、途中のタスク切り替えが残ります。"),
                    systemImage: "record.circle"
                )
                OnboardingHintRow(
                    title: String(localized: "あとから修正"),
                    body: String(localized: "記録を開いて内容や時間を直せます。タイマーを使い忘れたときは手動でも追加できます。"),
                    systemImage: "pencil"
                )
            }

        case .statistics:
            VStack(spacing: 8) {
                OnboardingHintRow(
                    title: String(localized: "週・月・年"),
                    body: String(localized: "集中時間、完了したタスク、タスクや分野ごとの時間配分を確認できます。"),
                    systemImage: "chart.xyaxis.line"
                )
                OnboardingHintRow(
                    title: String(localized: "集中カレンダー"),
                    body: String(localized: "色が濃いほど、その日に集中した時間が長かったことを表します。"),
                    systemImage: "calendar"
                )
            }

            OnboardingCallout(
                title: String(localized: "自分を採点するためではありません"),
                body: String(localized: "時間の使い方に気づき、次に何へ取り組むかを決めるための統計です。"),
                systemImage: "heart"
            )

        case .workflow:
            OnboardingWorkflowSummary()

        case .privacy:
            VStack(spacing: 8) {
                OnboardingCallout(
                    title: String(localized: "プライベートなデータ"),
                    body: String(localized: "データは端末内に保存されます。iCloudが有効な場合は、Apple Accountに紐づく非公開のCloudKitデータベースを通じて同期されます。タスクや履歴がThruFlow独自のサーバーへ送信されることはありません。"),
                    systemImage: "lock.shield"
                )
                OnboardingCallout(
                    title: String(localized: "基本機能は無料・広告なし"),
                    body: String(localized: "タスク、集中タイマー、履歴、統計などの基本機能は、無料・広告なしで利用できます。料金は一切かかりません。"),
                    systemImage: "heart.fill"
                )
            }
        }
    }

    private var navigationControls: some View {
        HStack(spacing: 10) {
            if store.step != .welcome {
                Button {
                    store.goBack()
                } label: {
                    Image(systemName: "chevron.backward")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(String(localized: "戻る"))
                .accessibilityIdentifier("onboarding.back.step.\(store.step.rawValue)")
            }

            Spacer()

            primaryButton
        }
    }

    @ViewBuilder
    private var primaryButton: some View {
        if store.experience == .undecided {
            ProgressView(String(localized: "iCloudのデータを確認しています…"))
                .controlSize(.small)
        } else {
            Button(action: performPrimaryAction) {
                HStack(spacing: 7) {
                    if store.demoState.isRunning, store.step == .demo {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(primaryButtonTitle)
                    if !store.step.isFinal,
                       !(store.step == .areas && store.canOfferAreaCreation),
                       !(store.step == .tasks && store.canOfferTaskCreation),
                       !(store.step == .demo && !store.demoState.isCompleted) {
                        Image(systemName: "chevron.forward")
                    }
                }
                .frame(minWidth: 112)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(store.demoState.isRunning || !primaryActionIsEnabled)
            .accessibilityIdentifier(primaryButtonIdentifier)
        }
    }

    private var primaryButtonTitle: String {
        if store.step == .areas, store.canOfferAreaCreation {
            return String(localized: "分野を作る")
        }
        if store.step == .tasks, store.canOfferTaskCreation {
            return String(localized: "タスクを作る")
        }
        if store.step == .demo, !store.demoState.isCompleted {
            return store.demoState.isRunning
                ? String(localized: "プレビュー中")
                : String(localized: "プレビューを見る")
        }
        if store.step.isFinal {
            return String(localized: "はじめる")
        }
        return String(localized: "次へ")
    }

    private var primaryButtonIdentifier: String {
        if store.step == .areas, store.canOfferAreaCreation {
            return "onboarding.create-area.step.\(store.step.rawValue)"
        }
        if store.step == .tasks, store.canOfferTaskCreation {
            return "onboarding.create-task.step.\(store.step.rawValue)"
        }
        if store.step == .demo, !store.demoState.isCompleted {
            return "onboarding.demo.start.step.\(store.step.rawValue)"
        }
        if store.step.isFinal {
            return "onboarding.finish.step.\(store.step.rawValue)"
        }
        return "onboarding.next.step.\(store.step.rawValue)"
    }

    private var primaryActionIsEnabled: Bool {
        switch store.step {
        case .areas where store.canOfferAreaCreation:
            true
        case .tasks where store.canOfferTaskCreation:
            true
        case .demo where !store.demoState.isCompleted:
            !store.demoState.isRunning
        default:
            store.canAdvance
        }
    }

    private func performPrimaryAction() {
        if store.step == .areas, store.canOfferAreaCreation {
            _ = store.requestAreaCreation()
        } else if store.step == .tasks, store.canOfferTaskCreation {
            _ = store.requestTaskCreation()
        } else if store.step == .demo, !store.demoState.isCompleted {
            _ = store.startDemo()
        } else {
            store.advance()
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 5) {
            ForEach(OnboardingStep.allCases, id: \.self) { step in
                Capsule()
                    .fill(step == store.step ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: step == store.step ? 18 : 6, height: 6)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct OnboardingHintRow: View {
    let title: String
    let detail: String
    let icon: OnboardingIcon

    init(title: String, body: String, systemImage: String) {
        self.title = title
        detail = body
        icon = .system(systemImage)
    }

    init(title: String, body: String, icon: OnboardingIcon) {
        self.title = title
        detail = body
        self.icon = icon
    }

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            OnboardingIconView(icon: icon, width: 18)
                .font(.body.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 11))
    }
}

private struct OnboardingCallout: View {
    let title: String
    let detail: String
    let systemImage: String

    init(title: String, body: String, systemImage: String) {
        self.title = title
        detail = body
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 11))
    }
}

private struct OnboardingModeSummary: View {
    private let modes = [
        OnboardingMode(title: String(localized: "短め"), detail: String(localized: "12分＋3分休憩"), icon: "hare"),
        OnboardingMode(title: String(localized: "標準"), detail: String(localized: "25分＋5分休憩"), icon: "target"),
        OnboardingMode(title: String(localized: "じっくり"), detail: String(localized: "50分＋10分休憩"), icon: "mountain.2.fill")
    ]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                ForEach(modes) { mode in
                    modeView(mode)
                }
            }
            VStack(spacing: 8) {
                ForEach(modes) { mode in
                    modeView(mode)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func modeView(_ mode: OnboardingMode) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(mode.title, systemImage: mode.icon)
                .font(.caption.weight(.semibold))
            Text(mode.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 11))
    }
}

private struct OnboardingMode: Identifiable {
    let title: String
    let detail: String
    let icon: String

    var id: String { title }
}

private struct OnboardingFlowDemo: View {
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
                    style: demoPanelStyle,
                    timer: FlowTimerPresentation(
                        progress: projection.timerProgress,
                        tint: timerTint(for: projection, taskTint: tint),
                        eyebrow: timerEyebrow(for: projection),
                        timeText: timerText(for: projection),
                        footer: FlowMode.sprint.displayName
                    )
                ) {
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
                    .foregroundStyle(.secondary)
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
                detail: nil,
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
                return demoPanelStyle == .dashboard ? .blue : taskTint
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

private struct OnboardingWorkflowSummary: View {
    private let stages: [OnboardingWorkflowStage] = [
        OnboardingWorkflowStage(title: String(localized: "分野"), icon: .system(ProductSymbol.area)),
        OnboardingWorkflowStage(title: String(localized: "タスク"), icon: .system("checklist")),
        OnboardingWorkflowStage(title: String(localized: "流れ"), icon: .flow),
        OnboardingWorkflowStage(title: String(localized: "履歴・統計"), icon: .system("chart.bar.xaxis")),
        OnboardingWorkflowStage(title: String(localized: "次の一歩"), icon: .system("arrow.forward.circle"))
    ]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            horizontalFlow
            verticalFlow
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "分野、タスク、流れ、履歴と統計、次の一歩"))
    }

    private var horizontalFlow: some View {
        HStack(spacing: 6) {
            ForEach(Array(stages.enumerated()), id: \.offset) { index, stage in
                stageLabel(stage)
                if index < stages.count - 1 {
                    Image(systemName: "chevron.forward")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .fixedSize()
    }

    private var verticalFlow: some View {
        VStack(spacing: 5) {
            ForEach(Array(stages.enumerated()), id: \.offset) { index, stage in
                stageLabel(stage)
                if index < stages.count - 1 {
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func stageLabel(_ stage: OnboardingWorkflowStage) -> some View {
        Label {
            Text(stage.title)
        } icon: {
            OnboardingIconView(icon: stage.icon, width: 14)
        }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.07), in: Capsule())
            .fixedSize()
    }
}

private struct OnboardingWorkflowStage {
    let title: String
    let icon: OnboardingIcon
}

fileprivate enum OnboardingIcon {
    case system(String)
    case flow
}

private struct OnboardingIconView: View {
    let icon: OnboardingIcon
    let width: CGFloat

    @ViewBuilder
    var body: some View {
        switch icon {
        case .system(let name):
            Image(systemName: name)
                .frame(width: width, height: width)
        case .flow:
            FlowMenuIcon(width: width)
                .frame(width: width, height: width)
        }
    }
}

extension OnboardingStep {
    var eyebrow: String {
        switch self {
        case .welcome: String(localized: "ようこそ")
        case .areas: String(localized: "分野")
        case .tasks: String(localized: "タスク")
        case .flow: String(localized: "流れ")
        case .timer: String(localized: "集中タイマー")
        case .demo: String(localized: "流れを体験")
        case .history: String(localized: "履歴")
        case .statistics: String(localized: "統計")
        case .workflow: String(localized: "使い方の流れ")
        case .privacy: String(localized: "データ")
        }
    }

    fileprivate var icon: OnboardingIcon {
        switch self {
        case .welcome: .system("hand.wave.fill")
        case .areas: .system(ProductSymbol.area)
        case .tasks: .system("checklist")
        case .flow: .flow
        case .timer: .system("timer")
        case .demo: .system("timer")
        case .history: .system("clock.arrow.circlepath")
        case .statistics: .system("chart.bar.xaxis")
        case .workflow: .system("arrow.triangle.2.circlepath")
        case .privacy: .system("lock.shield")
        }
    }

    var title: String {
        switch self {
        case .welcome: String(localized: "大切なことに集中しよう")
        case .areas: String(localized: "取り組むことを、分野で整理")
        case .tasks: String(localized: "やることを、具体的なタスクに")
        case .flow: String(localized: "今日の流れをひと目で")
        case .timer: String(localized: "タスクを選んで、集中を始める")
        case .demo: String(localized: "集中から休憩までを見てみよう")
        case .history: String(localized: "一日の記録を、あとから振り返る")
        case .statistics: String(localized: "時間の使い方に気づく")
        case .workflow: String(localized: "すべてが、ひとつの流れに")
        case .privacy: String(localized: "データと基本機能について")
        }
    }

    var body: String {
        switch self {
        case .welcome:
            String(localized: "ThruFlowは、タスク管理、柔軟な集中タイマー、時間の振り返りをひとつにまとめたアプリです。まずは分野とタスクをひとつずつ作り、基本の流れを試してみましょう。")
        case .areas:
            String(localized: "分野は、仕事・勉強・健康・家事など、日々取り組むことをまとめる枠です。タスクと集中時間が分野ごとにつながるので、何に時間を使ったか振り返りやすくなります。")
        case .tasks:
            String(localized: "タスクには、分野、優先度、日付、進捗の測り方を設定できます。ボタンから選ぶことも、入力中にショートカットを使うこともできます。")
        case .flow:
            String(localized: "流れの画面では、今日の作業、タスク、集中の記録、統計をまとめて確認できます。")
        case .timer:
            String(localized: "取り組むタスクと集中時間を選び、準備ができたら再生ボタンを押します。途中で変更しても、途切れない作業はひとつの流れとして残ります。")
        case .demo:
            String(localized: "タスクを選んで集中を始め、12分の集中が終わって3分の休憩に切り替わるまでを早送りで再現します。デモのため、履歴や統計には記録されません。実際には、集中後にメモを確認してから休憩を始めます。")
        case .history:
            String(localized: "履歴には、実際に行った集中、休憩、途中のタスク切り替えが自動で残ります。")
        case .statistics:
            String(localized: "統計では、集中時間、完了したタスク、タスクや分野ごとの時間配分を週・月・年で確認できます。")
        case .workflow:
            String(localized: "分野で取り組むことを整理し、タスクで次の一歩を決める。流れで実際の集中時間を記録し、履歴と統計で振り返る。ThruFlowは、このサイクルをひとつにつなげます。")
        case .privacy:
            String(localized: "最後に、データの保存先と無料で使える基本機能についてお伝えします。")
        }
    }
}
