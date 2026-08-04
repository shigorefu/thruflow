import SwiftUI

#if os(iOS)
private struct IOSSearchToolbarModifier: ViewModifier {
    @Binding var text: String
    @Binding var isPresented: Bool
    let prompt: String

    func body(content: Content) -> some View {
        Group {
            if isPresented {
                content.searchable(
                    text: $text,
                    isPresented: $isPresented,
                    placement: .toolbar,
                    prompt: Text(prompt)
                )
            } else {
                content
            }
        }
        .onChange(of: isPresented) { _, newValue in
            if !newValue {
                text = ""
            }
        }
    }
}

struct IOSSearchToolbarButton: View {
    @Binding var isPresented: Bool

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "magnifyingglass")
        }
        .accessibilityLabel(String(localized: "検索"))
    }
}

extension View {
    func iosCenteredNavigationTitle(_ title: String) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                        .accessibilityAddTraits(.isHeader)
                }
            }
    }

    func iosToolbarSearch(
        text: Binding<String>,
        isPresented: Binding<Bool>,
        prompt: String
    ) -> some View {
        modifier(
            IOSSearchToolbarModifier(
                text: text,
                isPresented: isPresented,
                prompt: prompt
            )
        )
    }
}
#endif
