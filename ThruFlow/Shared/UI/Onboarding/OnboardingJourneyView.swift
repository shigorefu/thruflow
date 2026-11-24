#if os(macOS) || os(iOS)
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
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.24), value: store.isPresented)
    }
}

private struct OnboardingJourneyOverlay: View {
    @ObservedObject var store: OnboardingStore

    var body: some View {
        ZStack {
            // Only the scrim extends beneath system bars and hardware regions.
            Color.black.opacity(0.64)
                .ignoresSafeArea()
                .contentShape(Rectangle())

            OnboardingJourneyCard(store: store)
#if os(macOS)
                .frame(maxWidth: 520)
#else
                .frame(maxWidth: 1_040, maxHeight: 680)
#endif
                .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.snappy(duration: 0.28, extraBounce: 0), value: store.step)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.journey")
    }
}

private struct OnboardingJourneyCard: View {
    @ObservedObject var store: OnboardingStore
#if os(macOS)
    @State private var stepContentHeight: CGFloat?
#else
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var minimumColumnWidth = 320.0
#endif

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            stepScrollView

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

    private var stepScrollView: some View {
#if os(macOS)
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    introduction
                    details
                }
                .padding(.vertical, 4)
                .id(ScrollAnchor.top)
                .onGeometryChange(for: CGFloat.self, of: { ceil($0.size.height) }) { height in
                    stepContentHeight = height
                }
            }
            // Use the natural content height when it fits. Keep the same scroll
            // view mounted when it doesn't so resizing won't reset the demo.
            .frame(maxHeight: stepContentHeight)
            .scrollBounceBehavior(.basedOnSize)
            .onChange(of: store.step) {
                proxy.scrollTo(ScrollAnchor.top, anchor: .top)
            }
        }
#else
        ScrollView {
            // A single Layout preserves the demo subtree while folding or resizing.
            OnboardingStepLayout(
                allowsColumns: horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize,
                minimumColumnWidth: minimumColumnWidth
            ) {
                introduction
                details
            }
            .padding(.vertical, 4)
        }
        .scrollBounceBehavior(.basedOnSize)
#endif
    }

#if os(macOS)
    private enum ScrollAnchor: Hashable {
        case top
    }
#endif

    private var details: some View {
        VStack(alignment: .leading, spacing: 14) { stepContent }
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(store.step.title)
                .font(.title2.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)

            Text(store.step.body)
                .font(.callout)
                .foregroundStyle(Color.primary.opacity(0.72))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                    .foregroundStyle(Color.primary.opacity(0.72))
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
                    title: String(localized: "フロー"),
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
                .foregroundStyle(Color.primary.opacity(0.72))
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
                        .fixedSize(horizontal: false, vertical: true)
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

/// A content-sized two-column slide with a stable introduction/example order.
/// The minimum is a readable column measure, not a device-size breakpoint.
private nonisolated struct OnboardingStepLayout: Layout {
    let allowsColumns: Bool
    let minimumColumnWidth: CGFloat
    private let spacing: CGFloat = 24

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = max(0, proposal.width ?? minimumColumnWidth)
        let columns = columnCount(width: width)
        let childWidth = max(0, (width - CGFloat(columns - 1) * spacing) / CGFloat(columns))
        let heights = subviews.map { $0.sizeThatFits(ProposedViewSize(width: childWidth, height: nil)).height }
        let height = columns == 2
            ? heights.max() ?? 0
            : heights.reduce(0, +) + CGFloat(max(0, heights.count - 1)) * spacing
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let columns = columnCount(width: bounds.width)
        let width = max(0, (bounds.width - CGFloat(columns - 1) * spacing) / CGFloat(columns))
        let childProposal = ProposedViewSize(width: width, height: nil)
        var y = bounds.minY
        for (index, subview) in subviews.enumerated() {
            let x = bounds.minX + (columns == 2 ? CGFloat(index) * (width + spacing) : 0)
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: childProposal)
            if columns == 1 { y += subview.sizeThatFits(childProposal).height + spacing }
        }
    }

    private func columnCount(width: CGFloat) -> Int {
        allowsColumns && width >= minimumColumnWidth * 2 + spacing ? 2 : 1
    }
}
#endif
