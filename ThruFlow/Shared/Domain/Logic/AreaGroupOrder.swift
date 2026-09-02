import Foundation

struct AreaGroupOrder {
    static let defaultValue: [AreaType] = [.neutral, .habit, .nice]

    static func decode(_ rawValue: String) -> [AreaType] {
        let storedTypes = rawValue
            .split(separator: ",")
            .compactMap { AreaType(rawValue: String($0)) }
        let uniqueStoredTypes = storedTypes.reduce(into: [AreaType]()) { result, type in
            if !result.contains(type) {
                result.append(type)
            }
        }

        return uniqueStoredTypes + defaultValue.filter { !uniqueStoredTypes.contains($0) }
    }

    static func encode(_ order: [AreaType]) -> String {
        normalized(order).map(\.rawValue).joined(separator: ",")
    }

    static func moving(
        _ source: AreaType,
        relativeTo target: AreaType,
        in order: [AreaType]
    ) -> [AreaType] {
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

    private static func normalized(_ order: [AreaType]) -> [AreaType] {
        let uniqueTypes = order.reduce(into: [AreaType]()) { result, type in
            if !result.contains(type) {
                result.append(type)
            }
        }
        return uniqueTypes + defaultValue.filter { !uniqueTypes.contains($0) }
    }
}
