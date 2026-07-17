//
//  LocalisationTests.swift
//  ThruFlowTests
//
//  Created by Codex on 2026/07/17.
//

import Foundation
import Testing

struct LocalisationTests {
    @Test func catalogUsesJapaneseAsSourceLanguage() throws {
        let data = try Data(contentsOf: catalogURL)
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(root["strings"] as? [String: Any])

        #expect(root["sourceLanguage"] as? String == "ja")
        #expect(strings.count >= 350)
        #expect(!data.contains(Data("\"extractionState\" : \"stale\"".utf8)))
    }

    @Test func japaneseAppLiteralsUseLocalisationAPI() throws {
        let sourceRoot = repositoryRoot.appending(path: "ThruFlow")
        let enumerator = try #require(
            FileManager.default.enumerator(
                at: sourceRoot,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
        )
        var violations: [String] = []

        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            for (offset, line) in source.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                guard containsJapaneseStringLiteral(String(line)) else { continue }
                guard !line.contains("String(localized:") else { continue }

                let relativePath = fileURL.path.replacingOccurrences(
                    of: repositoryRoot.path + "/",
                    with: ""
                )
                violations.append("\(relativePath):\(offset + 1)")
            }
        }

        #expect(violations.isEmpty, "Unlocalized Japanese literals: \(violations.joined(separator: ", "))")
    }

    @Test func catalogContainsCompleteEnglishAndRussianLocalisations() throws {
        let data = try Data(contentsOf: catalogURL)
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(root["strings"] as? [String: Any])
        var missing: [String] = []

        for (key, rawEntry) in strings {
            guard
                let entry = rawEntry as? [String: Any],
                let localisations = entry["localizations"] as? [String: Any]
            else {
                missing.append(key)
                continue
            }

            for language in ["en", "ru"] {
                guard
                    let localisation = localisations[language] as? [String: Any],
                    let stringUnit = localisation["stringUnit"] as? [String: Any],
                    stringUnit["state"] as? String == "translated",
                    let value = stringUnit["value"] as? String,
                    !value.isEmpty
                else {
                    missing.append("\(language):\(key)")
                    continue
                }

                #expect(
                    placeholderTypes(in: value) == placeholderTypes(in: key),
                    "Placeholder mismatch for \(language):\(key)"
                )
            }
        }

        #expect(missing.isEmpty, "Missing localisations: \(missing.joined(separator: ", "))")
    }

    @Test func catalogMatchesUnambiguousGlossaryTerms() throws {
        let data = try Data(contentsOf: catalogURL)
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(root["strings"] as? [String: Any])
        let glossary = try parseCSV(
            String(contentsOf: glossaryURL, encoding: .utf8)
        )
        let groupedRows = Dictionary(grouping: glossary.dropFirst()) { $0[2] }
        var mismatches: [String] = []

        for (japanese, rows) in groupedRows {
            let approvedPairs = Set(rows.map { "\($0[3])\u{0}\($0[4])" })
            guard approvedPairs.count == 1, let rawEntry = strings[japanese] else { continue }
            guard
                let entry = rawEntry as? [String: Any],
                let localisations = entry["localizations"] as? [String: Any],
                let english = localisedValue(language: "en", from: localisations),
                let russian = localisedValue(language: "ru", from: localisations),
                approvedPairs.contains("\(english)\u{0}\(russian)")
            else {
                mismatches.append(japanese)
                continue
            }
        }

        #expect(mismatches.isEmpty, "Glossary mismatches: \(mismatches.joined(separator: ", "))")
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var catalogURL: URL {
        repositoryRoot.appending(path: "ThruFlow/Localisation/Localizable.xcstrings")
    }

    private var glossaryURL: URL {
        repositoryRoot.appending(path: "Localisation/TERMS.csv")
    }

    private func localisedValue(language: String, from localisations: [String: Any]) -> String? {
        guard
            let localisation = localisations[language] as? [String: Any],
            let stringUnit = localisation["stringUnit"] as? [String: Any]
        else { return nil }
        return stringUnit["value"] as? String
    }

    private func placeholderTypes(in value: String) -> [String] {
        let pattern = #"%(?:\d+\$)?(?:lld|ld|d|f|@)"#
        let expression = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(value.startIndex..., in: value)
        return expression.matches(in: value, range: range).compactMap { match in
            guard let swiftRange = Range(match.range, in: value) else { return nil }
            return value[swiftRange]
                .replacingOccurrences(of: #"%\d+\$"#, with: "%", options: .regularExpression)
        }
    }

    private func parseCSV(_ source: String) throws -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var isQuoted = false
        var index = source.startIndex

        while index < source.endIndex {
            let character = source[index]
            if character == "\"" {
                let next = source.index(after: index)
                if isQuoted, next < source.endIndex, source[next] == "\"" {
                    field.append("\"")
                    index = next
                } else {
                    isQuoted.toggle()
                }
            } else if character == ",", !isQuoted {
                row.append(field)
                field = ""
            } else if character == "\n", !isQuoted {
                row.append(field)
                if !row.allSatisfy(\.isEmpty) { rows.append(row) }
                row = []
                field = ""
            } else if character != "\r" {
                field.append(character)
            }
            index = source.index(after: index)
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        guard rows.allSatisfy({ $0.count == 5 }) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return rows
    }

    private func containsJapaneseStringLiteral(_ line: String) -> Bool {
        line.range(
            of: #"\"[^\"\\]*(?:[ぁ-んァ-ヶ一-龯々ー])[^\"\\]*\""#,
            options: .regularExpression
        ) != nil
    }
}
