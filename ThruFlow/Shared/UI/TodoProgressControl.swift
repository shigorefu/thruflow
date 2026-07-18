//
//  TodoProgressControl.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/13.
//

import SwiftUI

struct TodoProgressControl: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let todo: Todo
    var additionalFocusSeconds: Int = 0
    let action: () -> Void

    @State private var checkmarkProgress: CGFloat = 0
    @State private var pulseScale: CGFloat = 0.72
    @State private var pulseOpacity: Double = 0
    @State private var hasAppeared = false

    @ViewBuilder
    var body: some View {
        Group {
            if todo.measurement == .checkbox {
                Button(action: action) {
                    checkbox
                }
                .buttonStyle(.plain)
                .accessibilityLabel(todo.isCompleted ? String(localized: "未完了に戻す") : String(localized: "完了にする"))
                .accessibilityValue(accessibilityValue)
            } else if todo.measurement == .focusBlocks {
                progressRing
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(String(localized: "ブロック進捗"))
                    .accessibilityValue(accessibilityValue)
            } else {
                minuteProgress
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(String(localized: "分の進捗"))
                    .accessibilityValue(accessibilityValue)
            }
        }
        .overlay {
            completionPulse
        }
        .onAppear {
            checkmarkProgress = todo.isCompleted ? 1 : 0
            hasAppeared = true
        }
        .onChange(of: todo.isCompleted) { wasCompleted, isCompleted in
            updateCompletionAnimation(
                wasCompleted: wasCompleted,
                isCompleted: isCompleted
            )
        }
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
                    animatedCheckmark
                        .stroke(
                            Color.white,
                            style: StrokeStyle(lineWidth: 2.1, lineCap: .round, lineJoin: .round)
                        )
                }
            }
            .frame(width: 20, height: 20)
            .frame(width: 34, height: 34)
            .contentShape(Rectangle())
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.22), lineWidth: 3)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))

            if todo.isCompleted {
                animatedCheckmark
                    .stroke(
                        tint,
                        style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
                    )
            }
        }
        .frame(width: 22, height: 22)
        .frame(width: 34, height: 34)
        .contentShape(Rectangle())
    }

    private var minuteProgress: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.16))

            ProgressPieShape(progress: progress)
                .fill(tint)

            if todo.isCompleted {
                animatedCheckmark
                    .stroke(
                        progress > 0.52 ? Color.white : tint,
                        style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round)
                    )
            } else {
                Image(systemName: "timer")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(progress > 0.52 ? Color.white : tint)
            }
        }
        .overlay {
            Circle().strokeBorder(tint.opacity(0.55), lineWidth: 1)
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

    private var animatedCheckmark: some Shape {
        CompletionCheckmarkShape()
            .trim(from: 0, to: checkmarkProgress)
    }

    private var completionPulse: some View {
        Circle()
            .stroke(tint.opacity(0.8), lineWidth: 2)
            .frame(width: 24, height: 24)
            .scaleEffect(pulseScale)
            .opacity(pulseOpacity)
            .allowsHitTesting(false)
    }

    private func updateCompletionAnimation(wasCompleted: Bool, isCompleted: Bool) {
        guard hasAppeared, wasCompleted != isCompleted else { return }

        if !isCompleted {
            if reduceMotion {
                checkmarkProgress = 0
            } else {
                withAnimation(.easeOut(duration: 0.16)) {
                    checkmarkProgress = 0
                }
            }
            return
        }

        TaskCompletionFeedbackPlayer.shared.play(for: todo.id)
        guard !reduceMotion else {
            checkmarkProgress = 1
            return
        }

        checkmarkProgress = 0
        pulseScale = 0.72
        pulseOpacity = 0.85

        withAnimation(.snappy(duration: 0.34, extraBounce: 0.18)) {
            checkmarkProgress = 1
        }
        withAnimation(.easeOut(duration: 0.46)) {
            pulseScale = 1.75
            pulseOpacity = 0
        }
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

private struct CompletionCheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.17, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.42, y: rect.maxY - rect.height * 0.22))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.14, y: rect.minY + rect.height * 0.2))
        return path
    }
}

private struct ProgressPieShape: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let value = min(max(progress, 0), 1)
        guard value > 0 else { return Path() }
        if value >= 1 { return Path(ellipseIn: rect) }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + 360 * value),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}
