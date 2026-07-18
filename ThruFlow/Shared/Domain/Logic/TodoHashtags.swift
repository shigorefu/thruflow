import Foundation

enum TodoHashtagNormalizer {
    static func normalize(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = String(trimmed.drop(while: { $0 == "#" }))
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !normalized.isEmpty else { continue }
            let comparisonKey = normalized.lowercased(with: Locale(identifier: "en_US_POSIX"))
            guard seen.insert(comparisonKey).inserted else { continue }
            result.append(normalized)
        }

        return result
    }
}

enum TodoHashtagCodec {
    static func encode(_ values: [String]) -> String? {
        let normalized = TodoHashtagNormalizer.normalize(values)
        guard !normalized.isEmpty,
              let data = try? JSONEncoder().encode(normalized) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func decode(_ rawValue: String?) -> [String] {
        guard let rawValue,
              let data = rawValue.data(using: .utf8),
              let values = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return TodoHashtagNormalizer.normalize(values)
    }
}
