import SwiftUI

extension View {
    /// Briefly soften a discrete content change without replacing the view's
    /// identity, scroll position, editor focus, or navigation stack.
    func productContentFade<Value: Equatable>(on value: Value) -> some View {
        modifier(ProductContentFade(trigger: value))
    }
}

private struct ProductContentFade<Trigger: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let trigger: Trigger

    func body(content: Content) -> some View {
        let motionEnabled = !reduceMotion
        content.keyframeAnimator(initialValue: 1.0, trigger: motionEnabled ? trigger : nil) { view, opacity in
            view.opacity(motionEnabled ? opacity : 1)
        } keyframes: { _ in
            MoveKeyframe(0.72)
            LinearKeyframe(1, duration: 0.18)
        }
    }
}

/// A system indicator centered within the portion of the screen awaiting data.
struct FeatureLoadingIndicator: View {
    var body: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
    }
}

extension View {
    /// A short, bounded reveal for the first rows of a newly loaded list.
    func featureRowReveal(
        index: Int,
        enabled: Bool,
        eligibleUntil: ContinuousClock.Instant? = nil
    ) -> some View {
        modifier(FeatureRowReveal(index: index, enabled: enabled, eligibleUntil: eligibleUntil))
    }
}

private struct FeatureRowReveal: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    let index: Int
    let enabled: Bool
    let eligibleUntil: ContinuousClock.Instant?

    private var reveals: Bool {
        guard enabled, !reduceMotion, (0..<5).contains(index), !hasAppeared else { return false }
        return eligibleUntil.map { ContinuousClock.now < $0 } ?? true
    }

    func body(content: Content) -> some View {
        content
            .opacity(reveals ? 0.45 : 1)
            .offset(y: reveals ? -5 : 0)
            .onAppear {
                guard !hasAppeared else { return }
                if reveals {
                    withAnimation(.easeOut(duration: 0.16).delay(Double(index) * 0.025)) {
                        hasAppeared = true
                    }
                } else {
                    hasAppeared = true
                }
            }
    }
}
