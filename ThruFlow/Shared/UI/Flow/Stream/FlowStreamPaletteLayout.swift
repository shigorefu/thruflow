import Foundation

enum FlowStreamPaletteLayout {
    static func ribbonColorHexes(
        palette: [String],
        weights: [Double],
        ribbonCount: Int
    ) -> [String] {
        guard ribbonCount > 0 else { return [] }

        let fallback = ["#0A84FF", "#30D5C8", "#BF5AF2", "#64D2FF"]
        let source = palette.isEmpty ? fallback : Array(palette.prefix(ribbonCount))
        let suppliedWeights = source.indices.map { index in
            guard index < weights.count, weights[index] > 0 else {
                return palette.isEmpty ? 1.0 : 0.0
            }
            return weights[index]
        }
        let effectiveWeights = suppliedWeights.reduce(0, +) > 0
            ? suppliedWeights
            : source.map { _ in 1.0 }
        let totalWeight = effectiveWeights.reduce(0, +)

        // Every active color gets a ribbon before duration decides how the
        // remaining visual capacity is distributed.
        var allocations = source.map { _ in 1 }
        var remaining = max(0, ribbonCount - allocations.reduce(0, +))
        while remaining > 0 {
            let allocatedTotal = allocations.reduce(0, +)
            let nextIndex = source.indices.max { lhs, rhs in
                let lhsDeficit = effectiveWeights[lhs] / totalWeight
                    - Double(allocations[lhs]) / Double(allocatedTotal + 1)
                let rhsDeficit = effectiveWeights[rhs] / totalWeight
                    - Double(allocations[rhs]) / Double(allocatedTotal + 1)
                if lhsDeficit == rhsDeficit {
                    return lhs > rhs
                }
                return lhsDeficit < rhsDeficit
            } ?? 0
            allocations[nextIndex] += 1
            remaining -= 1
        }

        // Smooth weighted round-robin keeps repeated dominant colors from
        // collecting into one solid vertical region.
        var distributed: [String] = []
        var emitted = source.map { _ in 0 }
        while distributed.count < ribbonCount {
            let available = source.indices.filter { emitted[$0] < allocations[$0] }
            let nextIndex = available.max { lhs, rhs in
                let lhsPriority = Double(allocations[lhs]) * Double(distributed.count + 1)
                    / Double(ribbonCount) - Double(emitted[lhs])
                let rhsPriority = Double(allocations[rhs]) * Double(distributed.count + 1)
                    / Double(ribbonCount) - Double(emitted[rhs])
                if lhsPriority == rhsPriority {
                    return lhs > rhs
                }
                return lhsPriority < rhsPriority
            } ?? 0
            distributed.append(source[nextIndex])
            emitted[nextIndex] += 1
        }

        return distributed
    }
}
