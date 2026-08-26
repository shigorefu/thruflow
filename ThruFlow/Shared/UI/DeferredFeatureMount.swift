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
        Group {
            if isActive, isMounted {
                content()
            } else {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(title)
        .task(id: isActive) {
            guard isActive else {
                isMounted = false
                return
            }

            await Task.yield()
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, isActive else { return }

            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                isMounted = true
            }
        }
    }
}
