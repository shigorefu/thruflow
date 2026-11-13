import Foundation

struct FlowPaletteTransition: Equatable {
    static let duration: TimeInterval = 2.4
    private(set) var previous: [String] = []
    private(set) var target: [String] = []
    private(set) var startedAt: Date?
    private(set) var pending: [String]?

    mutating func receive(_ colors: [String], at now: Date, animated: Bool) {
        advance(at: now)
        guard !target.isEmpty, animated else {
            previous = colors
            target = colors
            startedAt = nil
            pending = nil
            return
        }
        if startedAt != nil {
            pending = colors == target ? nil : colors
        } else if colors != target {
            previous = target
            target = colors
            startedAt = now
        }
    }

    mutating func advance(at now: Date) {
        guard let start = startedAt, now.timeIntervalSince(start) >= Self.duration else { return }
        previous = target
        startedAt = nil
        if let next = pending {
            pending = nil
            target = next
            startedAt = now
        }
    }

    func progress(at now: Date) -> Double {
        guard let startedAt else { return 1 }
        return min(1, max(0, now.timeIntervalSince(startedAt) / Self.duration))
    }
}
