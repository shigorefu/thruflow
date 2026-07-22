import SwiftUI

struct IOSMoreMenuLabel: View {
    var badgeCount = 0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "ellipsis")
                .rotationEffect(.degrees(90))
                .font(.body.weight(.semibold))
                .frame(width: 30, height: 30)
                .padding(.top, 7)

            if badgeCount > 0 {
                Text(badgeText)
                    .font(.caption2.monospacedDigit().weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, badgeCount > 9 ? 4 : 0)
                    .frame(minWidth: 16, minHeight: 16)
                    .background(.red, in: Capsule())
                    .offset(x: 6, y: -2)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: 34, height: 37)
        .contentShape(Rectangle())
    }

    private var badgeText: String {
        badgeCount > 99 ? "99+" : "\(badgeCount)"
    }
}
