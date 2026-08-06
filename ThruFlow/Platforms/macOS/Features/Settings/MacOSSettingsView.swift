//
//  MacOSSettingsView.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/17.
//

import SwiftData
import SwiftUI

struct MacOSSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var onboarding: OnboardingStore
    @State private var showsDeleteHistoryConfirmation = false
    @State private var isDeletingHistory = false
    @State private var deletionStatus: HistoryDeletionStatus?

    var body: some View {
        Form {
            Section(String(localized: "外観")) {
                Picker(String(localized: "テーマ"), selection: $settings.appearance) {
                    Text(String(localized: "システム設定に合わせる")).tag(AppAppearance.system)
                    Text(String(localized: "ライト")).tag(AppAppearance.light)
                    Text(String(localized: "ダーク")).tag(AppAppearance.dark)
                }
                .pickerStyle(.segmented)
            }

            Section(String(localized: "言語")) {
                Picker(String(localized: "言語"), selection: $settings.languageCode) {
                    ForEach(languageOptions, id: \.code) { option in
                        Text(option.name).tag(option.code)
                    }
                }

                if settings.requiresRestartForLanguage {
                    Label(String(localized: "言語はアプリの再起動後に適用されます"), systemImage: "arrow.clockwise")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section(String(localized: "カレンダー")) {
                Picker(String(localized: "週の開始日"), selection: $settings.weekStart) {
                    Text(String(localized: "システム設定に合わせる")).tag(AppWeekStart.system)
                    Text(String(localized: "日曜日")).tag(AppWeekStart.sunday)
                    Text(String(localized: "月曜日")).tag(AppWeekStart.monday)
                    Text(String(localized: "土曜日")).tag(AppWeekStart.saturday)
                }

                Picker(String(localized: "新しい日の開始"), selection: $settings.dayStartHour) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text(settings.dayStartLabel(for: hour)).tag(hour)
                    }
                }

                Text(String(localized: "設定した時刻までは前日のタスクとFlowとして扱います"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(String(localized: "時刻")) {
                Picker(String(localized: "時刻表示"), selection: $settings.clockFormat) {
                    Text(String(localized: "システム設定に合わせる")).tag(AppClockFormat.system)
                    Text(String(localized: "12時間制")).tag(AppClockFormat.twelveHour)
                    Text(String(localized: "24時間制")).tag(AppClockFormat.twentyFourHour)
                }
            }

            Section(String(localized: "タスク")) {
                Toggle(String(localized: "クイック入力のヒントを表示"), isOn: $settings.showsTaskQuickInputLegend)
            }

            Section(String(localized: "ヘルプ")) {
                Button {
                    onboarding.present()
                } label: {
                    Label(String(localized: "使い方を見る"), systemImage: "sparkles.rectangle.stack")
                }
            }

            historyDataSection

            SupportSettingsSection()
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 520)
        .navigationTitle(String(localized: "設定"))
        .alert(
            String(localized: "すべてのFlow履歴を削除しますか？"),
            isPresented: $showsDeleteHistoryConfirmation
        ) {
            Button(String(localized: "キャンセル"), role: .cancel) {}
            Button(String(localized: "すべて削除"), role: .destructive) {
                deleteAllHistory()
            }
        } message: {
            Text(String(localized: "すべての端末からFlowと休憩の履歴が削除されます。タスクと方向は残り、Flowから計算された進捗はリセットされます。この操作は取り消せません。"))
        }
    }

    private var historyDataSection: some View {
        Section(String(localized: "データ")) {
            Button(role: .destructive) {
                showsDeleteHistoryConfirmation = true
            } label: {
                Label(String(localized: "Flow履歴をすべて削除"), systemImage: "trash")
            }
            .disabled(isDeletingHistory || activeFlowStore.timerState != nil)

            if isDeletingHistory {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(String(localized: "Flow履歴を削除しています…"))
                }
                .foregroundStyle(.secondary)
            } else if activeFlowStore.timerState != nil {
                Label(
                    String(localized: "履歴を削除する前に、現在のFlowを終了してください。"),
                    systemImage: "timer"
                )
                .foregroundStyle(.secondary)
            } else if let deletionStatus {
                Label(deletionStatus.message, systemImage: deletionStatus.symbolName)
                    .foregroundStyle(deletionStatus.isError ? Color.red : Color.secondary)
            }

            Text(String(localized: "タスク、方向、タスクのメモは残ります。チェック済みタスクの状態も変更されません。"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func deleteAllHistory() {
        guard !isDeletingHistory else { return }
        isDeletingHistory = true
        deletionStatus = nil
        let deletionActor = FlowHistoryDeletionActor(modelContainer: modelContext.container)

        Task {
            do {
                _ = try await deletionActor.deleteAll()
                deletionStatus = .success
            } catch FlowHistoryDeletionError.activeFlowExists {
                deletionStatus = .activeFlow
            } catch {
                deletionStatus = .failure
            }
            isDeletingHistory = false
        }
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

#Preview {
    MacOSSettingsView()
        .environmentObject(ActiveFlowStore())
        .environmentObject(AppSettings())
        .environmentObject(OnboardingStore())
        .environmentObject(SupportPurchaseStore())
}

private enum HistoryDeletionStatus {
    case success
    case activeFlow
    case failure

    var message: String {
        switch self {
        case .success: String(localized: "Flow履歴を削除しました")
        case .activeFlow: String(localized: "履歴を削除する前に、現在のFlowを終了してください。")
        case .failure: String(localized: "Flow履歴を削除できませんでした")
        }
    }

    var symbolName: String {
        switch self {
        case .success: "checkmark.circle"
        case .activeFlow: "timer"
        case .failure: "exclamationmark.triangle"
        }
    }

    var isError: Bool {
        self == .failure
    }
}
