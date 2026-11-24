#if os(macOS) || os(iOS)
import Foundation
import SwiftUI

struct OnboardingWorkflowSummary: View {
    private let stages: [OnboardingWorkflowStage] = [
        OnboardingWorkflowStage(title: String(localized: "分野"), icon: .system(ProductSymbol.area)),
        OnboardingWorkflowStage(title: String(localized: "タスク"), icon: .system("checklist")),
        OnboardingWorkflowStage(title: String(localized: "フロー"), icon: .flow),
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
        .accessibilityLabel(String(localized: "分野、タスク、フロー、履歴と統計、次の一歩"))
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

#endif
