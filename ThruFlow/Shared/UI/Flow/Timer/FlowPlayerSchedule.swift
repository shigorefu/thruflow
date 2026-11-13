import SwiftUI

/// Keep clock updates inside the smallest view that needs the date.
nonisolated enum FlowPlayerSchedule: TimelineSchedule {
    case seconds(active: Bool)
    case boundary(Date?, revision: Date)
    case appDay(AppDayBoundary, Calendar, revision: Date)

    func entries(from startDate: Date, mode: Mode) -> some Sequence<Date> {
        sequence(first: startDate) { date in
            switch self {
            case .seconds(let active):
                return active ? date.addingTimeInterval(1) : nil
            case .boundary(let deadline, _):
                return deadline.flatMap { $0 > date ? $0 : nil }
            case .appDay(let boundary, let calendar, _):
                let day = boundary.day(containing: date, calendar: calendar)
                let next = boundary.interval(for: day, calendar: calendar).end
                return next > date ? next : nil
            }
        }
    }

    @MainActor static func display(for state: FlowTimerState?) -> Self {
        guard let state else { return .seconds(active: false) }
        let changesWithTime = state.phase == .focusing || state.phase == .breakTime ||
            (state.phase == .paused && state.pausedAt == nil)
        return .seconds(active: changesWithTime)
    }

    @MainActor static func overtime(for state: FlowTimerState?, revision: Date) -> Self {
        .boundary(state?.phase == .focusing ? state?.plannedEndAt : nil, revision: revision)
    }
}

/// Production Flow player chrome shared by the real player and onboarding.
/// The shell owns layout only; its callers own application state and actions.
