import SwiftUI

private struct IOSPeriodSwipeNavigationModifier: ViewModifier {
    let isEnabled: Bool
    let onNavigate: (Int) -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content
                .contentShape(Rectangle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 24)
                        .onEnded { value in
                            let horizontalDistance = value.predictedEndTranslation.width
                            let verticalDistance = value.predictedEndTranslation.height
                            guard abs(horizontalDistance) >= 44 else { return }
                            guard abs(horizontalDistance) > abs(verticalDistance) * 1.25 else { return }

                            onNavigate(horizontalDistance < 0 ? 1 : -1)
                        }
                )
        } else {
            content
        }
    }
}

extension View {
    func iosPeriodSwipeNavigation(
        isEnabled: Bool = true,
        onNavigate: @escaping (Int) -> Void
    ) -> some View {
        modifier(
            IOSPeriodSwipeNavigationModifier(
                isEnabled: isEnabled,
                onNavigate: onNavigate
            )
        )
    }
}
