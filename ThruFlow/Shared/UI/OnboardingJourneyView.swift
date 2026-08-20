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
        HStack(alignment: .center, spacing: 10) {
            Label(store.step.eyebrow, systemImage: store.step.iconName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)

            Spacer()
            pageIndicator

            Button(String(localized: "スキップ")) {
                store.skip()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("onboarding.skip")
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch store.step {
        case .welcome:
            OnboardingCallout(
                title: String(localized: "ひとつずつ試せます"),
                body: String(localized: "まず分野とタスクを作り、流れの短いプレビューを見ます。途中でいつでもスキップできます。"),
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
                    title: String(localized: "分"),
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
                    systemImage: "waveform.path"
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

            VStack(spacing: 8) {
                OnboardingCallout(
                    title: String(localized: "プライベートなデータ"),
                    body: String(localized: "データは端末内に保存されます。iCloudが有効な場合は、Apple Accountに紐づく非公開のCloudKitデータベースを通じて同期されます。タスクや履歴がThruFlow独自のサーバーへ送信されることはありません。"),
                    systemImage: "lock.shield"
                )
                OnboardingCallout(
                    title: String(localized: "基本機能は無料・広告なし"),
                    body: String(localized: "タスク、集中タイマー、履歴、統計などの基本機能は、無料・広告なしで利用できます。利用に必須の支払いはありません。"),
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
    let systemImage: String

    init(title: String, body: String, systemImage: String) {
        self.title = title
        detail = body
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: systemImage)
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
            let isBreak = projection.phase == .breakTime
            let breakInteraction = projection.breakStartedAt.map {
                FlowBreakInteraction(
                    sequence: 1,
                    kind: .started(isLong: false),
                    occurredAt: $0
                )
            }

            VStack(spacing: 10) {
                ZStack(alignment: .top) {
                    FlowStreamSurface(
                        blocks: projection.focusProgress * 0.5,
                        flowCount: projection.focusProgress > 0 ? 1 : 0,
                        palette: ["#007AFF", "#30D5C8", "#AF52DE"],
                        paletteWeights: [0.5, 0.3, 0.2],
                        dailySeed: 12_250_310,
                        isActive: store.demoState.isRunning && !isBreak,
                        mode: .sprint,
                        breakStyle: isBreak ? .regular : .none,
                        breakInteraction: breakInteraction,
                        isRenderingEnabled: true
                    )
                    .frame(height: 148)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    HStack(spacing: 8) {
                        Label(
                            isBreak ? String(localized: "休憩") : String(localized: "集中"),
                            systemImage: isBreak ? "cup.and.saucer.fill" : "timer"
                        )
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.regularMaterial, in: Capsule())

                        Spacer()

                        Text(String(
                            format: "%02d:%02d",
                            projection.remainingSeconds / 60,
                            projection.remainingSeconds % 60
                        ))
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.regularMaterial, in: Capsule())
                        .accessibilityHidden(true)
                    }
                    .padding(10)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(isBreak
                                        ? String(localized: "3分の休憩")
                                        : String(localized: "12分の集中を早送り中"))
                }

                ProgressView(value: projection.overallProgress)
                    .tint(isBreak ? .green : .accentColor)
                    .accessibilityHidden(true)

                Text(store.demoState.isCompleted
                     ? String(localized: "休憩に切り替わりました。実際の流れでは、このままタイマーが続きます。")
                     : String(localized: "タイマーを早送りしています。このプレビューは履歴や統計には保存されません。"))
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
}

private struct OnboardingWorkflowSummary: View {
    private let stages: [OnboardingWorkflowStage] = [
        OnboardingWorkflowStage(title: String(localized: "分野"), iconName: ProductSymbol.area),
        OnboardingWorkflowStage(title: String(localized: "タスク"), iconName: "checklist"),
        OnboardingWorkflowStage(title: String(localized: "流れ"), iconName: "waveform.path"),
        OnboardingWorkflowStage(title: String(localized: "履歴・統計"), iconName: "chart.bar.xaxis"),
        OnboardingWorkflowStage(title: String(localized: "次の一歩"), iconName: "arrow.forward.circle")
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
        Label(stage.title, systemImage: stage.iconName)
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
    let iconName: String
}

extension OnboardingStep {
    var eyebrow: String {
        switch self {
        case .welcome: String(localized: "ようこそ")
        case .areas: String(localized: "分野")
        case .tasks: String(localized: "タスク")
        case .flow, .demo: String(localized: "流れ")
        case .history: String(localized: "履歴")
        case .statistics: String(localized: "統計")
        case .workflow: String(localized: "使い方の流れ")
        }
    }

    var iconName: String {
        switch self {
        case .welcome: "hand.wave.fill"
        case .areas: ProductSymbol.area
        case .tasks: "checklist"
        case .flow, .demo: "waveform.path"
        case .history: "clock.arrow.circlepath"
        case .statistics: "chart.bar.xaxis"
        case .workflow: "arrow.triangle.2.circlepath"
        }
    }

    var title: String {
        switch self {
        case .welcome: String(localized: "大切なことに集中しよう")
        case .areas: String(localized: "取り組むことを、分野で整理")
        case .tasks: String(localized: "やることを、具体的なタスクに")
        case .flow: String(localized: "タスクを選んで、集中を始める")
        case .demo: String(localized: "流れを体験してみよう")
        case .history: String(localized: "一日の記録を、あとから振り返る")
        case .statistics: String(localized: "時間の使い方に気づく")
        case .workflow: String(localized: "すべてが、ひとつの流れに")
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
            String(localized: "流れは、今日の作業を進める中心の画面です。集中タイマー、今日のタスク、作業の流れ、今日の統計をまとめて確認できます。途中でタスクや長さを変えても、途切れない作業はひとつの流れとして残ります。")
        case .demo:
            String(localized: "短いプレビューで、タイマーが集中から休憩へ切り替わるまでの流れを見てみましょう。実際のタスク、進捗、履歴、統計には影響しません。")
        case .history:
            String(localized: "履歴には、実際に行った集中、休憩、途中のタスク切り替えが自動で残ります。")
        case .statistics:
            String(localized: "統計では、集中時間、完了したタスク、タスクや分野ごとの時間配分を週・月・年で確認できます。")
        case .workflow:
            String(localized: "分野で取り組むことを整理し、タスクで次の一歩を決める。流れで実際の集中時間を記録し、履歴と統計で振り返る。ThruFlowは、このサイクルをひとつにつなげます。")
        }
    }
}
