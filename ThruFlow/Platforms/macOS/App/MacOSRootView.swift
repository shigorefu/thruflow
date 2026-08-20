//
//  MacOSRootView.swift
//  ThruFlow
//
//  Created by エドワード on 2026/07/08.
//

import SwiftUI
import SwiftData

struct MacOSRootView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.appDayBoundary) private var dayBoundary
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore
    @EnvironmentObject private var onboarding: OnboardingStore

    @Query(sort: \Direction.updatedAt, order: .reverse) private var directions: [Direction]
    @Query private var onboardingTodos: [Todo]
    @Query private var onboardingFlowSessions: [FlowSession]
    @Query private var onboardingFlowBreaks: [FlowBreak]
    @State private var selection: AppSection? = .flow
    @State private var historyDate = Calendar.current.startOfDay(for: .now)
    @State private var didReconcileFlowProgress = false
    @State private var flowSnapshotCache: FlowDashboardSnapshot?
    @State private var flowTodoGroupsCache: FlowDashboardTodoGroups?
    @State private var statisticsPeriodCache: StatisticsPeriodSnapshot?

    init() {
        var todoDescriptor = FetchDescriptor<Todo>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\Todo.createdAt)]
        )
        todoDescriptor.fetchLimit = 1
        _onboardingTodos = Query(todoDescriptor)

        var sessionDescriptor = FetchDescriptor<FlowSession>(
            sortBy: [SortDescriptor(\FlowSession.startedAt)]
        )
        sessionDescriptor.fetchLimit = 1
        _onboardingFlowSessions = Query(sessionDescriptor)

        var breakDescriptor = FetchDescriptor<FlowBreak>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\FlowBreak.startedAt)]
        )
        breakDescriptor.fetchLimit = 1
        _onboardingFlowBreaks = Query(breakDescriptor)
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(selection: $selection) {
                    Label {
                        Text(String(localized: "Flow"))
                    } icon: {
                        FlowMenuIcon()
                    }
                        .tag(AppSection.flow)

                    Label(String(localized: "タスク"), systemImage: "checklist")
                        .tag(AppSection.tasks)

                    Label(String(localized: "履歴"), systemImage: "clock.arrow.circlepath")
                        .tag(AppSection.history)

                    Label(String(localized: "方向"), systemImage: ProductSymbol.area)
                        .tag(AppSection.directions)

                    Label(String(localized: "統計"), systemImage: "chart.bar.xaxis")
                        .tag(AppSection.statistics)
                }

                Divider()

                SettingsLink {
                    Label(String(localized: "設定"), systemImage: "gearshape")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .navigationTitle(String(localized: "スルフロ"))
            .navigationSplitViewColumnWidth(min: 175, ideal: 190, max: 240)
        } detail: {
            detailContent
        }
        .task {
            historyDate = dayBoundary.day(containing: .now, calendar: calendar)
            guard !didReconcileFlowProgress else { return }
            didReconcileFlowProgress = true
            let modelContainer = modelContext.container
            try? await Task.sleep(for: .milliseconds(750))
            guard !Task.isCancelled else { return }
            let reconciler = FlowProgressReconciliationActor(modelContainer: modelContainer)
            try? await reconciler.reconcileAll()
        }
        .onAppear {
            showOnboardingScreenIfNeeded()
        }
        .task(id: onboardingWorkspaceHasUserContent) {
            await resolveOnboardingExperience()
        }
        .onChange(of: onboarding.step) { _, _ in
            showOnboardingScreenIfNeeded()
        }
        .onChange(of: onboarding.isPresented) { _, isPresented in
            if isPresented {
                showOnboardingScreenIfNeeded()
            } else {
                selection = .flow
            }
        }
        .onOpenURL(perform: openWidgetURL)
        .sheet(item: onboardingPresentationBinding) { presentation in
            onboardingSheet(for: presentation)
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selection ?? .flow {
        case .flow:
            DeferredFeatureMount(
                isActive: (selection ?? .flow) == .flow,
                title: String(localized: "Flow")
            ) {
                FlowDashboardView(
                    isVisible: !onboarding.isPresented,
                    directions: directions,
                    cachedSnapshot: $flowSnapshotCache,
                    cachedTodoGroups: $flowTodoGroupsCache
                )
            }
        case .tasks:
            TasksView()
        case .history:
            DayHistoryView(initialDate: historyDate)
                .id(historyDate)
        case .directions:
            DirectionListView()
        case .statistics:
            DeferredFeatureMount(
                isActive: selection == .statistics,
                title: String(localized: "統計")
            ) {
                StatisticsView(
                    isVisible: true,
                    directions: directions,
                    cachedSnapshot: $statisticsPeriodCache
                ) { date in
                    historyDate = calendar.startOfDay(for: date)
                    selection = .history
                }
            }
        }
    }

    private func showOnboardingScreenIfNeeded() {
        guard onboarding.isPresented else { return }
        selection = switch onboarding.step.screen {
        case .flow: .flow
        case .directions: .directions
        case .tasks: .tasks
        case .history: .history
        case .statistics: .statistics
        }
    }

    private var onboardingPresentationBinding: Binding<OnboardingPresentation?> {
        Binding(
            get: { onboarding.presentation },
            set: { presentation in
                if presentation == nil {
                    onboarding.dismissPresentation()
                }
            }
        )
    }

    @ViewBuilder
    private func onboardingSheet(for presentation: OnboardingPresentation) -> some View {
        switch presentation {
        case .areaEditor:
            DirectionFormView(
                mode: .create,
                initialDraft: onboardingAreaDraft
            ) { direction in
                onboarding.resolveWorkspace(
                    hasUserContent: hasExternalOnboardingWorkspaceContent(
                        excludingAreaID: direction.id
                    )
                )
                _ = onboarding.recordArea(id: direction.id)
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(String(localized: "ガイドをスキップ")) {
                        onboarding.skip()
                    }
                }
            }

        case .taskComposer:
            if let area = onboardingCreatedArea {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label(String(localized: "最初のタスクを作る"), systemImage: "checklist")
                            .font(.headline)

                        Spacer()

                        Button(String(localized: "ガイドをスキップ")) {
                            onboarding.skip()
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }

                    QuickTodoCreationPopover(
                        directions: activeOnboardingDirections,
                        scheduledDate: dayBoundary.day(containing: .now, calendar: calendar),
                        showsQuickInputLegend: true,
                        initialDraft: onboardingTaskDraft(area: area)
                    ) { todo in
                        onboarding.resolveWorkspace(
                            hasUserContent: hasExternalOnboardingWorkspaceContent(
                                excludingTaskID: todo.id
                            )
                        )
                        guard let area = todo.direction else { return }
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
                }
                .padding(18)
            } else {
                ContentUnavailableView(
                    String(localized: "分野が見つかりません"),
                    systemImage: ProductSymbol.area
                )
                .frame(width: 420, height: 260)
            }
        }
    }

    private var activeOnboardingDirections: [Direction] {
        directions.filter { !$0.isArchived && !DefaultDirections.isTaskInboxRecord($0) }
    }

    private var onboardingCreatedArea: Direction? {
        guard let id = onboarding.createdAreaID else { return nil }
        return directions.first { $0.id == id && !$0.isArchived }
    }

    private var onboardingAreaDraft: DirectionDraft {
        DirectionDraft(
            name: String(localized: "仕事"),
            type: .neutral,
            symbolName: "💼",
            colorHex: "#007AFF"
        )
    }

    private func onboardingTaskDraft(area: Direction) -> TodoDraft {
        TodoDraft(
            title: String(localized: "レポートを仕上げる"),
            direction: area,
            measurement: .checkbox,
            priority: .medium,
            scheduledDate: dayBoundary.day(containing: .now, calendar: calendar)
        )
    }

    private var onboardingWorkspaceHasUserContent: Bool {
        hasExternalOnboardingWorkspaceContent()
    }

    private func hasExternalOnboardingWorkspaceContent(
        excludingAreaID: UUID? = nil,
        excludingTaskID: UUID? = nil
    ) -> Bool {
        OnboardingWorkspaceInspector.inspect(
            directions: directions.filter {
                $0.id != onboarding.createdAreaID && $0.id != excludingAreaID
            },
            todos: onboardingTodos.filter {
                $0.id != onboarding.createdTaskID && $0.id != excludingTaskID
            },
            flowSessions: onboardingFlowSessions,
            flowBreaks: onboardingFlowBreaks
        ).hasUserContent
    }

    private func resolveOnboardingExperience() async {
        guard onboarding.isPresented else { return }

        if onboardingWorkspaceHasUserContent {
            onboarding.resolveWorkspace(hasUserContent: true)
            return
        }

        if onboarding.launchKind == .firstRun,
           onboarding.experience == .undecided,
           AppModelContainerFactory.usesCloudKitForCurrentProcess {
            await OnboardingWorkspaceSettler.waitForInitialImportOrTimeout()
            guard !Task.isCancelled else { return }
        }

        onboarding.resolveWorkspace(hasUserContent: onboardingWorkspaceHasUserContent)
    }

    private func openWidgetURL(_ url: URL) {
        guard url.scheme == "thruflow" else { return }
        selection = switch url.host {
        case "flow": .flow
        case "tasks": .tasks
        case "statistics": .statistics
        default: selection
        }
    }
}

private enum AppSection: Hashable {
    case flow
    case tasks
    case history
    case directions
    case statistics
}

#Preview {
    MacOSRootView()
        .environmentObject(ActiveFlowStore())
        .environmentObject(OnboardingStore())
        .modelContainer(for: [Direction.self, Todo.self, FlowSession.self, FlowSegment.self, FlowBreak.self], inMemory: true)
}
