#if os(macOS) || os(iOS)
import Foundation
import SwiftUI

enum OnboardingIcon {
    case system(String)
    case flow
}

struct OnboardingIconView: View {
    let icon: OnboardingIcon
    let width: CGFloat

    @ViewBuilder
    var body: some View {
        switch icon {
        case .system(let name):
            Image(systemName: name)
                .frame(width: width, height: width)
        case .flow:
            FlowMenuIcon(width: width)
                .frame(width: width, height: width)
        }
    }
}

extension OnboardingStep {
    var eyebrow: String {
        switch self {
        case .welcome: String(localized: "ようこそ")
        case .areas: String(localized: "分野")
        case .tasks: String(localized: "タスク")
        case .flow: String(localized: "フロー")
        case .timer: String(localized: "集中タイマー")
        case .demo: String(localized: "フローを体験")
        case .history: String(localized: "履歴")
        case .statistics: String(localized: "統計")
        case .workflow: String(localized: "使い方のフロー")
        case .privacy: String(localized: "データ")
        }
    }

    var icon: OnboardingIcon {
        switch self {
        case .welcome: .system("hand.wave.fill")
        case .areas: .system(ProductSymbol.area)
        case .tasks: .system("checklist")
        case .flow: .flow
        case .timer: .system("timer")
        case .demo: .system("timer")
        case .history: .system("clock.arrow.circlepath")
        case .statistics: .system("chart.bar.xaxis")
        case .workflow: .system("arrow.triangle.2.circlepath")
        case .privacy: .system("lock.shield")
        }
    }

    var title: String {
        switch self {
        case .welcome: String(localized: "大切なことに集中しよう")
        case .areas: String(localized: "取り組むことを、分野で整理")
        case .tasks: String(localized: "やることを、具体的なタスクに")
        case .flow: String(localized: "今日のフローをひと目で")
        case .timer: String(localized: "タスクを選んで、集中を始める")
        case .demo: String(localized: "集中から休憩までを見てみよう")
        case .history: String(localized: "一日の記録を、あとから振り返る")
        case .statistics: String(localized: "時間の使い方に気づく")
        case .workflow: String(localized: "すべてが、ひとつのフローに")
        case .privacy: String(localized: "データと基本機能について")
        }
    }

    var body: String {
        switch self {
        case .welcome:
            String(localized: "ThruFlowは、タスク管理、柔軟な集中タイマー、時間の振り返りをひとつにまとめたアプリです。まずは分野とタスクをひとつずつ作り、基本のフローを試してみましょう。")
        case .areas:
            String(localized: "分野は、仕事・勉強・健康・家事など、日々取り組むことをまとめる枠です。タスクと集中時間が分野ごとにつながるので、何に時間を使ったか振り返りやすくなります。")
        case .tasks:
            String(localized: "タスクには、分野、優先度、日付、進捗の測り方を設定できます。ボタンから選ぶことも、入力中にショートカットを使うこともできます。")
        case .flow:
            String(localized: "フローの画面では、今日の作業、タスク、集中の記録、統計をまとめて確認できます。")
        case .timer:
            String(localized: "取り組むタスクと集中時間を選び、準備ができたら再生ボタンを押します。途中で変更しても、途切れない作業はひとつのフローとして残ります。")
        case .demo:
            String(localized: "タスクを選んで集中を始め、12分の集中が終わって3分の休憩に切り替わるまでを早送りで再現します。デモのため、履歴や統計には記録されません。実際には、集中後にメモを確認してから休憩を始めます。")
        case .history:
            String(localized: "履歴には、実際に行った集中、休憩、途中のタスク切り替えが自動で残ります。")
        case .statistics:
            String(localized: "統計では、集中時間、完了したタスク、タスクや分野ごとの時間配分を週・月・年で確認できます。")
        case .workflow:
            String(localized: "分野で取り組むことを整理し、タスクで次の一歩を決める。フローで実際の集中時間を記録し、履歴と統計で振り返る。ThruFlowは、このサイクルをひとつにつなげます。")
        case .privacy:
            String(localized: "最後に、データの保存先と無料で使える基本機能についてお伝えします。")
        }
    }
}

#endif
