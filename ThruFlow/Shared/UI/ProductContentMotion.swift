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
