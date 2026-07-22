import SwiftUI

struct IOSMoreMenuLabel: View {
    var body: some View {
        Image(systemName: "ellipsis")
            .rotationEffect(.degrees(90))
            .font(.body.weight(.semibold))
            .frame(width: 32, height: 32)
            .frame(width: 36, height: 36)
            .contentShape(Circle())
    }
}

struct IOSNotificationBadge: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Text(badgeText)
                .font(.caption2.monospacedDigit().weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, count > 9 ? 4 : 0)
                .frame(minWidth: 16, minHeight: 16)
                .background(.red, in: Capsule())
                .accessibilityHidden(true)
        }
    }

    private var badgeText: String {
        count > 99 ? "99+" : "\(count)"
    }
}
