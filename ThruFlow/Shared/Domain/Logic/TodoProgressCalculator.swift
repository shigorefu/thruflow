//
//  TodoProgressCalculator.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/08.
//

import Foundation

struct TodoProgressCalculator {
    func progress(
        measurement: TodoMeasurement,
        plannedAmount: Int?,
        actualProgress: Int
    ) -> Double {
        switch measurement {
        case .checkbox:
            return actualProgress > 0 ? 1 : 0
        case .focusBlocks, .minutes:
            guard let plannedAmount, plannedAmount > 0 else { return 0 }
            return min(Double(max(0, actualProgress)) / Double(plannedAmount), 1)
        }
    }

    func status(
        measurement: TodoMeasurement,
        plannedAmount: Int?,
        actualProgress: Int
    ) -> TodoStatus {
        progress(
            measurement: measurement,
            plannedAmount: plannedAmount,
            actualProgress: actualProgress
        ) >= 1 ? .completed : .active
    }

    func summary(
        measurement: TodoMeasurement,
        plannedAmount: Int?,
        actualProgress: Int,
        focusDurationSeconds: Int? = nil
    ) -> String {
        switch measurement {
        case .checkbox:
            return actualProgress > 0 ? String(localized: "完了") : String(localized: "未完了")
        case .focusBlocks:
            if let focusDurationSeconds {
                return BlockUnit.progressText(
                    focusedSeconds: focusDurationSeconds,
                    targetBlocks: plannedAmount ?? 0
                )
            }

            return String(localized: "\(max(0, actualProgress))/\(plannedAmount ?? 0) ブロック")
        case .minutes:
            return String(localized: "\(max(0, actualProgress))/\(plannedAmount ?? 0) 分")
        }
    }
}
