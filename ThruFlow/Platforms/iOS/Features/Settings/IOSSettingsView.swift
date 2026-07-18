import SwiftUI

struct IOSSettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Form {
            Section(String(localized: "外観")) {
                Picker(String(localized: "テーマ"), selection: $settings.appearance) {
                    Text(String(localized: "システム設定に合わせる")).tag(AppAppearance.system)
                    Text(String(localized: "ライト")).tag(AppAppearance.light)
                    Text(String(localized: "ダーク")).tag(AppAppearance.dark)
                }
            }

            Section(String(localized: "言語と地域")) {
                Picker(String(localized: "言語"), selection: $settings.languageCode) {
                    ForEach(languageOptions, id: \.code) { option in
                        Text(option.name).tag(option.code)
                    }
                }

                if settings.requiresRestartForLanguage {
                    Label(
                        String(localized: "言語はアプリの再起動後に適用されます"),
                        systemImage: "arrow.clockwise"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Picker(String(localized: "週の開始日"), selection: $settings.weekStart) {
                    Text(String(localized: "システム設定に合わせる")).tag(AppWeekStart.system)
                    Text(String(localized: "日曜日")).tag(AppWeekStart.sunday)
                    Text(String(localized: "月曜日")).tag(AppWeekStart.monday)
                    Text(String(localized: "土曜日")).tag(AppWeekStart.saturday)
                }

                Picker(String(localized: "時刻表示"), selection: $settings.clockFormat) {
                    Text(String(localized: "システム設定に合わせる")).tag(AppClockFormat.system)
                    Text(String(localized: "12時間制")).tag(AppClockFormat.twelveHour)
                    Text(String(localized: "24時間制")).tag(AppClockFormat.twentyFourHour)
                }
            }
        }
        .navigationTitle(String(localized: "設定"))
    }

    private var languageOptions: [(code: String, name: String)] {
        var codes = Bundle.main.localizations
            .filter { $0 != "Base" }
            .map { Locale(identifier: $0).language.languageCode?.identifier ?? $0 }

        if settings.languageCode != AppSettings.systemLanguageCode {
            codes.append(settings.languageCode)
        }

        let uniqueCodes = Array(Set(codes)).sorted { lhs, rhs in
            languageName(for: lhs).localizedStandardCompare(languageName(for: rhs)) == .orderedAscending
        }

        return [(AppSettings.systemLanguageCode, String(localized: "システム設定に合わせる"))] +
            uniqueCodes.map { ($0, languageName(for: $0)) }
    }

    private func languageName(for code: String) -> String {
        Locale.autoupdatingCurrent.localizedString(forIdentifier: code) ?? code
    }
}
