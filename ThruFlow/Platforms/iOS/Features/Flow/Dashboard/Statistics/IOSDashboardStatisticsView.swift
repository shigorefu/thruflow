#if os(iOS)
import SwiftUI

struct IOSDashboardStatisticsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let snapshot: FlowDashboardSnapshot?
    let recentRecords: IOSFlowRecentRecords?
    let todos: [Todo]
    let todoGroups: FlowDashboardTodoGroups?
    let calendar: Calendar
    let dayBoundary: AppDayBoundary

    @State private var page = IOSDashboardStatisticsPage.distribution
    @State private var distributionMode = IOSDashboardDistributionMode.task

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label(String(localized: "統計"), systemImage: "chart.bar.xaxis")
                    .font(.headline)
                Spacer()
                HStack(spacing: 5) {
                    ForEach(IOSDashboardStatisticsPage.allCases) { value in
                        Circle()
                            .fill(value == page ? Color.accentColor : Color.secondary.opacity(0.25))
                            .frame(width: 5, height: 5)
                    }
                }
            }

            Text(page.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Group {
                switch page {
                case .distribution:
                    if let snapshot {
                        IOSDashboardDistributionPage(
                            snapshot: snapshot,
                            distributionMode: $distributionMode
                        )
                    } else {
                        loadingPage
                    }
                case .trend:
                    if let snapshot, let recentRecords {
                        IOSDashboardTrendPage(
                            snapshot: snapshot,
                            records: recentRecords,
                            todos: todos,
                            calendar: calendar,
                            dayBoundary: dayBoundary
                        )
                    } else {
                        loadingPage
                    }
                case .achievement:
                    if let todoGroups {
                        IOSDashboardAchievementPage(todoGroups: todoGroups)
                    } else {
                        loadingPage
                    }
                }
            }
            .id(page)
            .transition(reduceMotion ? .identity : .opacity)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 330, alignment: .topLeading)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
        .iosHorizontalPeriodSwipe { offset in
            movePage(offset)
        }
    }

    private var loadingPage: some View {
        ProgressView()
            .frame(maxWidth: .infinity, minHeight: 220)
    }

    private func movePage(_ offset: Int) {
        let pages = IOSDashboardStatisticsPage.allCases
        guard let current = pages.firstIndex(of: page) else { return }
        let next = (current + offset + pages.count) % pages.count
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.22)) {
            page = pages[next]
        }
    }

}

private enum IOSDashboardStatisticsPage: Int, CaseIterable, Identifiable {
    case distribution
    case trend
    case achievement

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .distribution: String(localized: "時間配分")
        case .trend: String(localized: "Flow推移")
        case .achievement: String(localized: "達成状況")
        }
    }
}
#endif
