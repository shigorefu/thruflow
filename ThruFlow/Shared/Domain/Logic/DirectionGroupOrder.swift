import Foundation

struct DirectionGroupOrder {
    static let defaultValue: [DirectionType] = [.neutral, .habit, .nice]

    static func decode(_ rawValue: String) -> [DirectionType] {
        let storedTypes = rawValue
            .split(separator: ",")
            .compactMap { DirectionType(rawValue: String($0)) }
        let uniqueStoredTypes = storedTypes.reduce(into: [DirectionType]()) { result, type in
            if !result.contains(type) {
                result.append(type)
            }
        }

        return uniqueStoredTypes + defaultValue.filter { !uniqueStoredTypes.contains($0) }
    }

    static func encode(_ order: [DirectionType]) -> String {
        normalized(order).map(\.rawValue).joined(separator: ",")
    }

    static func moving(
        _ source: DirectionType,
        relativeTo target: DirectionType,
        in order: [DirectionType]
    ) -> [DirectionType] {
        var result = normalized(order)
        guard source != target,
              let sourceIndex = result.firstIndex(of: source),
              let originalTargetIndex = result.firstIndex(of: target) else { return result }

        let movedType = result.remove(at: sourceIndex)
        guard let targetIndex = result.firstIndex(of: target) else { return result }
        let insertionIndex = sourceIndex < originalTargetIndex ? targetIndex + 1 : targetIndex
        result.insert(movedType, at: insertionIndex)
        return result
    }

    private static func normalized(_ order: [DirectionType]) -> [DirectionType] {
        let uniqueTypes = order.reduce(into: [DirectionType]()) { result, type in
            if !result.contains(type) {
                result.append(type)
            }
        }
        return uniqueTypes + defaultValue.filter { !uniqueTypes.contains($0) }
    }
}
