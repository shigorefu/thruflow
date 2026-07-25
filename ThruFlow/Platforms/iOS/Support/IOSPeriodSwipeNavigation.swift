import SwiftUI

private struct IOSPeriodSwipeNavigationModifier<PageID: Hashable>: ViewModifier {
    let pageID: PageID
    let isEnabled: Bool
    let onNavigate: (Int) -> Void

    @State private var navigationDirection = 1

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            ZStack(alignment: .top) {
                content
                    .id(pageID)
                    .transition(pageTransition)
            }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .clipped()
                .contentShape(Rectangle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 24)
                        .onEnded { value in
                            let horizontalDistance = value.predictedEndTranslation.width
                            let verticalDistance = value.predictedEndTranslation.height
                            guard abs(horizontalDistance) >= 44 else { return }
                            guard abs(horizontalDistance) > abs(verticalDistance) * 1.25 else { return }

                            let direction = horizontalDistance < 0 ? 1 : -1
                            navigationDirection = direction
                            withAnimation(.snappy(duration: 0.28)) {
                                onNavigate(direction)
                            }
                        }
                )
        } else {
            content
        }
    }

    private var pageTransition: AnyTransition {
        let insertionEdge: Edge = navigationDirection > 0 ? .trailing : .leading
        let removalEdge: Edge = navigationDirection > 0 ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: insertionEdge).combined(with: .opacity),
            removal: .move(edge: removalEdge).combined(with: .opacity)
        )
    }
}

extension View {
    func iosPeriodSwipeNavigation<PageID: Hashable>(
        pageID: PageID,
        isEnabled: Bool = true,
        onNavigate: @escaping (Int) -> Void
    ) -> some View {
        modifier(
            IOSPeriodSwipeNavigationModifier(
                pageID: pageID,
                isEnabled: isEnabled,
                onNavigate: onNavigate
            )
        )
    }

    func iosHorizontalPeriodSwipe(
        isEnabled: Bool = true,
        onNavigate: @escaping (Int) -> Void
    ) -> some View {
        simultaneousGesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    guard isEnabled else { return }
                    let horizontalDistance = value.predictedEndTranslation.width
                    let verticalDistance = value.predictedEndTranslation.height
                    guard abs(horizontalDistance) >= 44 else { return }
                    guard abs(horizontalDistance) > abs(verticalDistance) * 1.25 else { return }

                    withAnimation(.snappy(duration: 0.28)) {
                        onNavigate(horizontalDistance < 0 ? 1 : -1)
                    }
                }
        )
    }
}
