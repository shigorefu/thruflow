import SwiftUI

struct IOSMoreMenuLabel: View {
    var badgeCount = 0

    var body: some View {
        Image(systemName: "ellipsis")
            .rotationEffect(.degrees(90))
            .font(.body.weight(.semibold))
            .frame(width: 32, height: 32)
            .overlay(alignment: .topTrailing) {
                if badgeCount > 0 {
                    Text(badgeText)
                        .font(.caption2.monospacedDigit().weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, badgeCount > 9 ? 4 : 0)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(.red, in: Capsule())
                        .offset(x: 7, y: -8)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: 36, height: 36)
            .contentShape(Circle())
    }

    private var badgeText: String {
        badgeCount > 99 ? "99+" : "\(badgeCount)"
    }
}
