//
//  TodoProgressControl.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/13.
//

import SwiftUI

struct TodoProgressControl: View {
    let todo: Todo
    var additionalFocusSeconds: Int = 0
    let action: () -> Void

    @ViewBuilder
    var body: some View {
        if todo.measurement == .checkbox {
            Button(action: action) {
                checkbox
            }
            .buttonStyle(.plain)
            .accessibilityLabel(todo.isCompleted ? "未完了に戻す" : "完了にする")
            .accessibilityValue(accessibilityValue)
        } else {
            progressRing(systemImage: todo.measurement == .minutes ? "timer" : completionSymbol)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(todo.measurement == .focusBlocks ? "ブロック進捗" : "分の進捗")
                .accessibilityValue(accessibilityValue)
        }
    }

    private var completionSymbol: String? {
        todo.isCompleted ? "checkmark" : nil
    }

    private var checkbox: some View {
        RoundedRectangle(cornerRadius: 5)
            .strokeBorder(tint, lineWidth: 1.6)
            .background {
                RoundedRectangle(cornerRadius: 5)
                    .fill(todo.isCompleted ? tint : Color.clear)
            }
            .overlay {
                if todo.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 20, height: 20)
            .frame(width: 34, height: 34)
            .contentShape(Rectangle())
    }

    private func progressRing(systemImage: String?) -> some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.22), lineWidth: 3)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))

            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(tint)
            }
        }
        .frame(width: 22, height: 22)
        .frame(width: 34, height: 34)
        .contentShape(Rectangle())
    }

    private var progress: Double {
        if todo.measurement == .focusBlocks,
           let plannedAmount = todo.plannedAmount,
           plannedAmount > 0 {
            return min(BlockUnit.blocks(forFocusedSeconds: displayedFocusSeconds) / Double(plannedAmount), 1)
        }

        if todo.measurement == .minutes,
           let plannedAmount = todo.plannedAmount,
           plannedAmount > 0 {
            return min(Double(displayedFocusSeconds) / 60 / Double(plannedAmount), 1)
        }

        return TodoProgressCalculator().progress(
            measurement: todo.measurement,
            plannedAmount: todo.plannedAmount,
            actualProgress: todo.actualProgress
        )
    }

    private var displayedFocusSeconds: Int {
        todo.recordedFocusSeconds + max(0, additionalFocusSeconds)
    }

    private var tint: Color {
        guard let direction = todo.direction, !DefaultDirections.isTaskInbox(direction) else {
            return Color.secondary.opacity(0.6)
        }
        return Color(hex: direction.colorHex)
    }

    private var accessibilityValue: String {
        TodoProgressCalculator().summary(
            measurement: todo.measurement,
            plannedAmount: todo.plannedAmount,
            actualProgress: todo.actualProgress,
            focusDurationSeconds: displayedFocusSeconds
        )
    }
}
