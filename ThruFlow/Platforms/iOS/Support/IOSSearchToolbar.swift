import SwiftUI

#if os(iOS)
private struct IOSSearchToolbarModifier: ViewModifier {
    @Binding var text: String
    @Binding var isPresented: Bool
    let prompt: String

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            searchableContent(content)
                .searchToolbarBehavior(.minimize)
        } else {
            searchableContent(content)
        }
    }

    private func searchableContent(_ content: Content) -> some View {
        content
            .searchable(
                text: $text,
                isPresented: $isPresented,
                placement: .toolbar,
                prompt: Text(prompt)
            )
            .onChange(of: isPresented) { _, newValue in
                if !newValue {
                    text = ""
                }
            }
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
