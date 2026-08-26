//
//  LocalisationTests.swift
//  ThruFlowTests
//
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
                let usesLocalisationAPI = line.contains("String(localized:") ||
                    line.contains("LocalizedStringResource") ||
                    line.contains("IntentDescription(")
                let isDocumentedPersistenceLiteral = line.contains(
                    "// localisation-audit: persisted-value"
                )
                guard !usesLocalisationAPI, !isDocumentedPersistenceLiteral else { continue }

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

    @Test func japaneseCopyUsesNativeProductLanguage() throws {
        let data = try Data(contentsOf: catalogURL)
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(root["strings"] as? [String: Any])
        let expectedTerms = [
            "Flow": "流れ",
            "方向": "分野",
            "通常": "いつでも",
            "ナイス": "できたら",
            "Sprint": "短め",
            "Focus": "標準",
            "Deep": "じっくり",
            "Blocks": "ブロック",
            "Dots": "集中カレンダー",
            "Flow Dots": "集中カレンダー",
            "Elastic": "自動調整",
            "Inbox": "日付なし",
            "Activities": "スポーツ・趣味",
            "Food": "食べ物・飲み物",
            "Nature": "自然",
            "Objects": "もの",
            "People": "人・表情",
            "Recent": "最近使ったもの",
            "Symbols": "記号",
            "Travel": "乗り物・場所",
            "Work & Study": "仕事・勉強",
            "オート": "自動",
            "フローブロック": "集中ブロック",
            "週回": "週に数回",
        ]

        for (key, expected) in expectedTerms {
            #expect(
                try japaneseValue(for: key, in: strings) == expected,
                "Unexpected Japanese product term for \(key)"
            )
        }

        let prohibitedFragments = [
            "Flow", "Block", "Dots", "方向", "ナイス", "週回", "Sprint", "Focus",
            "Deep", "Elastic", "Inbox",
        ]
        let prohibitedExactValues = Set([
            "Activities", "Blocks", "Deep", "Dots", "Elastic", "Focus", "Food",
            "Inbox", "Nature", "Objects", "People", "Recent", "Sprint", "Symbols",
            "Travel", "Work & Study",
        ])
        var violations: [String] = []

        for key in strings.keys.sorted() {
            let value = try japaneseValue(for: key, in: strings)
            let copyWithoutBrand = value.replacingOccurrences(of: "ThruFlow", with: "")
            if prohibitedFragments.contains(where: { copyWithoutBrand.contains($0) }) ||
                prohibitedExactValues.contains(value) {
                violations.append("\(key)=\(value)")
            }
        }

        #expect(
            violations.isEmpty,
            "Unnatural Japanese product copy: \(violations.joined(separator: ", "))"
        )
    }

    @Test func englishAndRussianCopyUsesContextualProductLanguage() throws {
        let data = try Data(contentsOf: catalogURL)
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(root["strings"] as? [String: Any])
        let expectedTerms: [String: (english: String, russian: String)] = [
            "方向": ("Areas", "Сферы"),
            "分野": ("Area", "Сфера"),
            "タスク": ("Tasks", "Задачи"),
            "対象タスク": ("Task", "Задача"),
            "時間": ("Time", "Время"),
            "時間単位": ("Hours", "Часы"),
            "完了": ("Done", "Готово"),
            "完了済み": ("Completed", "Выполнена"),
            "終了": ("End", "Окончание"),
            "開始": ("Start", "Начало"),
            "日": ("Day", "День"),
            "日曜短縮": ("Sun", "Вс"),
            "月": ("Month", "Месяц"),
            "月曜短縮": ("Mon", "Пн"),
            "通常": ("Anytime", "Обычное"),
            "ナイス": ("Optional", "Если получится"),
            "Sprint": ("Short", "Короткий"),
            "Focus": ("Standard", "Обычный"),
            "Deep": ("Deep", "Глубокий"),
            "Dots": ("Focus Calendar", "Календарь фокуса"),
            "Flow Dots": ("Focus Calendar", "Календарь фокуса"),
            "フローブロック": ("Focus Blocks", "Блоки фокуса"),
            "集中ブロック": ("Focus Blocks", "Блоки фокуса"),
            "アプリのデータをリセット": ("Reset App Data", "Сбросить данные приложения"),
            "アプリのデータをリセットしますか？": ("Reset App Data?", "Сбросить данные приложения?"),
            "リセット": ("Reset", "Сбросить"),
        ]

        for (key, expected) in expectedTerms {
            let entry = try #require(strings[key] as? [String: Any])
            let localisations = try #require(entry["localizations"] as? [String: Any])

            #expect(
                localisedValue(language: "en", from: localisations) == expected.english,
                "Unexpected English product term for \(key)"
            )
            #expect(
                localisedValue(language: "ru", from: localisations) == expected.russian,
                "Unexpected Russian product term for \(key)"
            )
        }

        var legacyAreaTerms: [String] = []
        for (key, rawEntry) in strings {
            guard
                let entry = rawEntry as? [String: Any],
                let localisations = entry["localizations"] as? [String: Any]
            else { continue }

            if let english = localisedValue(language: "en", from: localisations),
               english.range(of: #"\bdirections?\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
                legacyAreaTerms.append("en:\(key)")
            }
            if let russian = localisedValue(language: "ru", from: localisations),
               russian.range(of: "направ", options: [.caseInsensitive]) != nil {
                legacyAreaTerms.append("ru:\(key)")
            }
        }

        #expect(
            legacyAreaTerms.isEmpty,
            "Legacy Area terms: \(legacyAreaTerms.sorted().joined(separator: ", "))"
        )
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

    private func japaneseValue(for key: String, in strings: [String: Any]) throws -> String {
        guard
            let entry = strings[key] as? [String: Any],
            let localisations = entry["localizations"] as? [String: Any],
            let japanese = localisedValue(language: "ja", from: localisations)
        else {
            return key
        }
        return japanese
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
