//
//  DeferredFeatureMount.swift
//  ThruFlow
//
//

import SwiftUI

/// Gives navigation one frame to commit before constructing a feature whose
/// SwiftData queries or charts may perform main-actor work during initialization.
struct DeferredFeatureMount<Content: View>: View {
    let isActive: Bool
    let title: String
    let delay: Duration
    private let content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isMounted = false

    init(
        isActive: Bool,
        title: String,
        delay: Duration = .milliseconds(60),
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isActive = isActive
        self.title = title
        self.delay = delay
        self.content = content
    }

    var body: some View {
        ZStack {
            if isActive, isMounted {
                content()
                    .transition(reduceMotion ? .identity : .opacity)
            } else if isActive {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .animation(reduceMotion || !isActive ? nil : .smooth(duration: 0.20), value: isMounted)
        .navigationTitle(title)
        .task(id: isActive) {
            guard isActive else {
                isMounted = false
                return
            }

            await Task.yield()
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, isActive else { return }

            isMounted = true
        }
    }
}
