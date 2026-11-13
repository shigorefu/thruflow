#if os(macOS) || os(iOS)
import Foundation
import SwiftUI

struct OnboardingHintRow: View {
    let title: String
    let detail: String
    let icon: OnboardingIcon

    init(title: String, body: String, systemImage: String) {
        self.title = title
        detail = body
        icon = .system(systemImage)
    }

    init(title: String, body: String, icon: OnboardingIcon) {
        self.title = title
        detail = body
        self.icon = icon
    }

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            OnboardingIconView(icon: icon, width: 18)
                .font(.body.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color.primary.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 11))
    }
}

struct OnboardingCallout: View {
    let title: String
    let detail: String
    let systemImage: String

    init(title: String, body: String, systemImage: String) {
        self.title = title
        detail = body
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color.primary.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 11))
    }
}

#endif
