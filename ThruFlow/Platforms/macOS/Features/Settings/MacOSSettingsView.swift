//
//  MacOSSettingsView.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/17.
//

import SwiftData
import SwiftUI
import AppKit

struct MacOSSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var activeFlowStore: ActiveFlowStore
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var onboarding: OnboardingStore
    @State private var showsResetConfirmation = false
    @State private var isResetting = false
    @State private var resetStatus: AppResetStatus?

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
                    let settingsWindow = NSApp.keyWindow
                    openWindow(id: MacOSWindowID.main)
                    dismiss()
                    settingsWindow?.performClose(nil)
                    Task { @MainActor in
                        await Task.yield()
                        NSApp.activate(ignoringOtherApps: true)
                        onboarding.presentReplay()
                    }
                } label: {
                    Label(String(localized: "使い方を見る"), systemImage: "sparkles.rectangle.stack")
                }
            }

            SupportSettingsSection()

            appDataSection
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 520)
        .navigationTitle(String(localized: "設定"))
        .alert(
            String(localized: "アプリのデータをリセットしますか？"),
            isPresented: $showsResetConfirmation
        ) {
            Button(String(localized: "キャンセル"), role: .cancel) {}
            Button(String(localized: "リセット"), role: .destructive) {
                resetAppData()
            }
        } message: {
            Text(String(localized: "タスク、分野、集中履歴、メモが、iCloudで同期しているすべての端末から削除されます。この端末の設定は残ります。この操作は取り消せません。"))
        }
    }

    private var appDataSection: some View {
        Section(String(localized: "データ")) {
            Button(role: .destructive) {
                showsResetConfirmation = true
            } label: {
                Label(String(localized: "アプリのデータをリセット"), systemImage: "arrow.counterclockwise")
            }
            .accessibilityIdentifier("settings.reset-app-data")
            .disabled(isResetting || activeFlowStore.timerState != nil)

            if isResetting {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(String(localized: "アプリのデータをリセットしています…"))
                }
                .foregroundStyle(.secondary)
            } else if activeFlowStore.timerState != nil {
                Label(
                    String(localized: "リセットする前に、現在のFlowを終了してください。"),
                    systemImage: "timer"
                )
                .foregroundStyle(.secondary)
            } else if let resetStatus {
                Label(resetStatus.message, systemImage: resetStatus.symbolName)
                    .foregroundStyle(resetStatus.isError ? Color.red : Color.secondary)
            }

            Text(String(localized: "タスク、分野、集中履歴、メモがすべて削除されます。設定は残ります。"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func resetAppData() {
        guard !isResetting else { return }
        isResetting = true
        resetStatus = nil
        let resetActor = AppDataResetActor(modelContainer: modelContext.container)

        Task {
            do {
                _ = try await resetActor.reset()
                activeFlowStore.resetAfterApplicationDataReset()
                let settingsWindow = NSApp.keyWindow
                openWindow(id: MacOSWindowID.main)
                dismiss()
                settingsWindow?.performClose(nil)
                await Task.yield()
                NSApp.activate(ignoringOtherApps: true)
                onboarding.presentAfterApplicationDataReset()
            } catch AppDataResetError.activeFlowExists {
                resetStatus = .activeFlow
            } catch {
                resetStatus = .failure
            }
            isResetting = false
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

private enum AppResetStatus {
    case activeFlow
    case failure

    var message: String {
        switch self {
        case .activeFlow: String(localized: "リセットする前に、現在のFlowを終了してください。")
        case .failure: String(localized: "アプリのデータをリセットできませんでした")
        }
    }

    var symbolName: String {
        switch self {
        case .activeFlow: "timer"
        case .failure: "exclamationmark.triangle"
        }
    }

    var isError: Bool {
        self == .failure
    }
}
