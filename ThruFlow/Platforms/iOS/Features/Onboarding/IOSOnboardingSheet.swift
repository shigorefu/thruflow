#if os(iOS)
import SwiftUI

struct IOSOnboardingSheet: View {
    @ObservedObject var onboarding: OnboardingStore
    let presentation: OnboardingPresentation
    let areas: [Area]
    let calendar: Calendar
    let dayBoundary: AppDayBoundary
    let hasExternalWorkspaceContent: (_ excludingAreaID: UUID?, _ excludingTaskID: UUID?) -> Bool

    @ViewBuilder
    var body: some View {
        switch presentation {
        case .areaEditor:
            NavigationStack {
                IOSAreaEditorView(
                    mode: .create(),
                    initialDraft: onboardingAreaDraft
                ) { area in
                    onboarding.resolveWorkspace(
                        hasUserContent: hasExternalWorkspaceContent(area.id, nil)
                    )
                    _ = onboarding.recordArea(id: area.id)
                }
                .toolbar {
                    ToolbarItem(placement: .bottomBar) {
                        Button(String(localized: "ガイドをスキップ")) {
                            onboarding.skip()
                        }
                    }
                }
            }
            .interactiveDismissDisabled(false)

        case .taskComposer:
            NavigationStack {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    if let area = onboardingCreatedArea {
                        IOSTaskComposer(
                            areas: activeOnboardingAreas,
                            initialDraft: onboardingTaskDraft(area: area),
                            onClose: onboarding.dismissPresentation
                        ) { todo in
                            onboarding.resolveWorkspace(
                                hasUserContent: hasExternalWorkspaceContent(nil, todo.id)
                            )
                            guard let area = todo.area else { return }
                            _ = onboarding.recordTask(
                                id: todo.id,
                                presentation: OnboardingTaskPresentation(
                                    title: TodoDisplay.title(for: todo),
                                    areaName: area.name,
                                    areaSymbol: area.symbolName,
                                    areaColorHex: area.colorHex
                                )
                            )
                        }
                    } else {
                        ContentUnavailableView(
                            String(localized: "分野が見つかりません"),
                            systemImage: ProductSymbol.area
                        )
                    }
                }
                .background(Color(.systemGroupedBackground))
                .iosCenteredNavigationTitle(String(localized: "最初のタスクを作る"))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "キャンセル")) {
                            onboarding.dismissPresentation()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "ガイドをスキップ")) {
                            onboarding.skip()
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .interactiveDismissDisabled(false)
        }
    }

    private var activeOnboardingAreas: [Area] {
        areas.filter { !$0.isArchived && !DefaultAreas.isTaskInboxRecord($0) }
    }

    private var onboardingCreatedArea: Area? {
        guard let id = onboarding.createdAreaID else { return nil }
        return areas.first { $0.id == id && !$0.isArchived }
    }

    private var onboardingAreaDraft: AreaDraft {
        AreaDraft(
            name: String(localized: "仕事"),
            type: .neutral,
            symbolName: "💼",
            colorHex: "#007AFF"
        )
    }

    private func onboardingTaskDraft(area: Area) -> TodoDraft {
        TodoDraft(
            title: String(localized: "レポートを仕上げる"),
            area: area,
            measurement: .checkbox,
            priority: .medium,
            scheduledDate: dayBoundary.day(containing: .now, calendar: calendar)
        )
    }
}
#endif
