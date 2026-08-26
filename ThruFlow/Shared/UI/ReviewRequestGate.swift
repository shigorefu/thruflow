import StoreKit
import SwiftData
import SwiftUI

struct ReviewRequestGate: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.modelContext) private var modelContext
    @Environment(\.requestReview) private var requestReview

    @State private var promptStore = ReviewPromptStore()
    @State private var isChecking = false

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .task {
                await checkEligibility(delay: .zero)
            }
            .onReceive(NotificationCenter.default.publisher(for: .flowDidComplete)) { _ in
                Task {
                    await checkEligibility(delay: .seconds(1.5))
                }
            }
    }

    @MainActor
    private func checkEligibility(delay: Duration) async {
        guard !isChecking, !isDisabledForTesting else { return }
        isChecking = true
        defer { isChecking = false }

        if delay != .zero {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
        }

        var descriptor = FetchDescriptor<FlowSession>(
            predicate: #Predicate { $0.completedAt != nil },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 50

        let sessions: [FlowSession]
        do {
            sessions = try modelContext.fetch(descriptor)
        } catch {
            PersistenceIssueCenter.shared.log(error, operation: .dataLoad)
            return
        }
        let activeDays = Set(sessions.compactMap { session in
            session.completedAt.map { calendar.startOfDay(for: $0) }
        })
        let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1"
        let usage = ReviewPromptUsage(
            firstLaunchAt: promptStore.firstLaunchAt,
            completedFlowCount: sessions.count,
            activeDayCount: activeDays.count,
            lastRequestedVersion: promptStore.lastRequestedVersion
        )

        guard ReviewPromptPolicy(calendar: calendar).isEligible(
            usage: usage,
            currentVersion: currentVersion,
            now: .now
        ) else { return }

        promptStore.markRequested(version: currentVersion)
        requestReview()
    }

    private var isDisabledForTesting: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("--uitesting") || arguments.contains("--onboarding-preview")
    }
}
