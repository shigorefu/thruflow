#if os(macOS) || os(iOS)
import Foundation
import SwiftUI

struct OnboardingModeSummary: View {
    private let modes = [
        OnboardingMode(title: String(localized: "短め"), detail: String(localized: "12分＋3分休憩"), icon: "hare"),
        OnboardingMode(title: String(localized: "標準"), detail: String(localized: "25分＋5分休憩"), icon: "target"),
        OnboardingMode(title: String(localized: "じっくり"), detail: String(localized: "50分＋10分休憩"), icon: "mountain.2.fill")
    ]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                ForEach(modes) { mode in
                    modeView(mode)
                }
            }
            VStack(spacing: 8) {
                ForEach(modes) { mode in
                    modeView(mode)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func modeView(_ mode: OnboardingMode) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(mode.title, systemImage: mode.icon)
                .font(.caption.weight(.semibold))
            Text(mode.detail)
                .font(.caption2)
                .foregroundStyle(Color.primary.opacity(0.72))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 11))
    }
}

private struct OnboardingMode: Identifiable {
    let title: String
    let detail: String
    let icon: String

    var id: String { title }
}

#endif
