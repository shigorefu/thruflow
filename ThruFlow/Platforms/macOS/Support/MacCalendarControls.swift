import SwiftUI

#if os(macOS)
struct MacCalendarNavigationHeader<RangePicker: View>: View {
    let title: String
    let onPrevious: () -> Void
    let onToday: () -> Void
    let onNext: () -> Void
    @ViewBuilder let rangePicker: RangePicker

    var body: some View {
        VStack(spacing: 0) {
            rangePicker
                .frame(width: 150)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            Divider()

            HStack(spacing: 12) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)

                Spacer(minLength: 16)

                HStack(spacing: 8) {
                    Button(action: onPrevious) {
                        Image(systemName: "chevron.left")
                    }
                    .accessibilityLabel(String(localized: "前へ"))

                    Button(String(localized: "今日"), action: onToday)
                        .buttonStyle(.borderedProminent)

                    Button(action: onNext) {
                        Image(systemName: "chevron.right")
                    }
                    .accessibilityLabel(String(localized: "次へ"))
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.bar)
    }
}

struct MacToolbarSearchControl: View {
    @Binding var text: String
    @Binding var isPresented: Bool

    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if isPresented {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField(String(localized: "検索"), text: $text)
                        .textFieldStyle(.plain)
                        .focused($isFocused)

                    Button {
                        text = ""
                        withAnimation(.easeInOut(duration: 0.18)) {
                            isPresented = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "閉じる"))
                }
                .padding(.horizontal, 9)
                .frame(width: 220, height: 30)
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .onAppear {
                    isFocused = true
                }
                .onExitCommand {
                    text = ""
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isPresented = false
                    }
                }
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isPresented = true
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .keyboardShortcut("f", modifiers: .command)
                .help(String(localized: "検索"))
                .accessibilityLabel(String(localized: "検索"))
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isPresented)
    }
}
#endif
