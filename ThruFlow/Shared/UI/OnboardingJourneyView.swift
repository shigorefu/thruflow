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
            let cardWidth = min(460, max(280, proxy.size.width - 32))

            ZStack {
                Color.black.opacity(0.64)
                    .contentShape(Rectangle())

                ScrollView {
                    OnboardingJourneyCard(store: store)
                        .frame(width: cardWidth)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .frame(minHeight: proxy.size.height, alignment: .center)
                }
                .scrollIndicators(.hidden)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Label(store.step.eyebrow, systemImage: store.step.iconName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tint)

                Spacer()
                pageIndicator

                Button(String(localized: "スキップ")) {
                    store.complete()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("onboarding.skip")
            }

            Text(store.step.title)
                .font(.title2.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)

            Text(store.step.body)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            if let detail = store.step.detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            }

            if store.step == .workflow {
                OnboardingWorkflowSummary()

                Label(
                    String(localized: "無料・広告なし・サブスクリプションなし・アカウント登録不要"),
                    systemImage: "heart.fill"
                )
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            }

            navigationControls
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16))
        }
        .shadow(color: .black.opacity(0.3), radius: 26, y: 10)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(store.step.title)
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

            Button {
                store.advance()
            } label: {
                HStack(spacing: 7) {
                    Text(store.step.isFinal ? String(localized: "ThruFlowを始める") : String(localized: "続ける"))
                    if !store.step.isFinal {
                        Image(systemName: "chevron.forward")
                    }
                }
                .frame(minWidth: 112)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier(
                store.step.isFinal
                    ? "onboarding.finish.step.\(store.step.rawValue)"
                    : "onboarding.next.step.\(store.step.rawValue)"
            )
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

private struct OnboardingWorkflowSummary: View {
    private let stages: [OnboardingWorkflowStage] = [
        OnboardingWorkflowStage(title: String(localized: "方向"), iconName: "point.3.connected.trianglepath.dotted"),
        OnboardingWorkflowStage(title: String(localized: "タスク"), iconName: "checklist"),
        OnboardingWorkflowStage(title: String(localized: "Flow"), iconName: "waveform.path"),
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
        .accessibilityLabel(String(localized: "方向、タスク、Flow、履歴と統計、次の一歩"))
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
        case .flow: String(localized: "Flow")
        case .directions: String(localized: "方向")
        case .tasks: String(localized: "タスク")
        case .history: String(localized: "履歴")
        case .statistics: String(localized: "統計")
        case .workflow: String(localized: "使い方の流れ")
        }
    }

    var iconName: String {
        switch self {
        case .welcome: "hand.wave.fill"
        case .flow: "waveform.path"
        case .directions: "point.3.connected.trianglepath.dotted"
        case .tasks: "checklist"
        case .history: "clock.arrow.circlepath"
        case .statistics: "chart.bar.xaxis"
        case .workflow: "arrow.triangle.2.circlepath"
        }
    }

    var title: String {
        switch self {
        case .welcome: String(localized: "ThruFlowへようこそ")
        case .flow: String(localized: "今日を進める中心")
        case .directions: String(localized: "時間を向ける先を決める")
        case .tasks: String(localized: "意図を、今日の一歩に")
        case .history: String(localized: "一日の流れを振り返る")
        case .statistics: String(localized: "集中のリズムに気づく")
        case .workflow: String(localized: "すべてが、ひとつの流れになる")
        }
    }

    var body: String {
        switch self {
        case .welcome:
            String(localized: "タスク、習慣、集中した時間を、ひとつのわかりやすいFlowにつなげます。1分で基本を見てみましょう。")
        case .flow:
            String(localized: "Flow画面は、今日の作業を進める中心です。タスクを選び、Sprint・Focus・Deepから今の自分に合う長さで集中します。タイマー、今日の流れ、タスク、今日の統計をひとつの画面で確認できます。")
        case .directions:
            String(localized: "方向は、仕事・学習・健康・読書のように、継続して時間を向けたいテーマです。関連するタスク、Flow、統計をひとつにまとめます。")
        case .tasks:
            String(localized: "タスクは今日できる具体的な行動です。チェック、集中ブロック、分の3つから、進捗の測り方を選べます。")
        case .history:
            String(localized: "履歴には実際のFlow、休憩、タスクの切り替えが残ります。記録が違っていたときは、あとから正しく直せます。")
        case .statistics:
            String(localized: "週・月・年ごとに、集中時間の傾向、タスクや方向への時間配分、日々のDotsを確認できます。自分を採点するためではなく、次に時間を向ける先を選ぶための統計です。")
        case .workflow:
            String(localized: "方向を決め、今日のタスクに落とし込み、Flowで実際の集中時間を記録します。履歴と統計で振り返ったら、次に時間を向ける先を選びます。")
        }
    }

    var detail: String? {
        switch self {
        case .flow:
            String(localized: "途中でタスクや長さを変えても、連続した作業はひとつのFlowとして記録されます。休憩は3・5・10分、4ブロックごとに20分の長休憩です。")
        case .directions:
            String(localized: "通常は計画する活動、習慣は決めた日に現れる活動、ナイスはできたらうれしい活動です。")
        case .tasks:
            String(localized: "1集中ブロックは25分。短いFlowは同じタスクの進捗として積み重なり、休憩は含まれません。")
        case .history:
            String(localized: "途中でタスクを変えても、連続した作業はひとつのFlowのままです。各タスクの時間は別々に集計されます。")
        default:
            nil
        }
    }
}
