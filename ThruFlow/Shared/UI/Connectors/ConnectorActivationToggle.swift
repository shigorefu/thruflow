#if os(macOS) || os(iOS)
import SwiftData
import SwiftUI

struct ConnectorActivationToggle: View {
    @EnvironmentObject private var connectors: ConnectorStore
    let provider: ConnectorProviderID

    var body: some View {
        Toggle(isOn: Binding(
            get: { connectors.connection(for: provider)?.isEnabled == true },
            set: { enabled in
                do { try connectors.setEnabled(enabled, for: provider) }
                catch { connectors.errorMessage = error.localizedDescription }
            }
        )) {
            Text(provider.connectorTitle)
        }
        .toggleStyle(.switch)
        .disabled(connectors.connection(for: provider) == nil || connectors.busyProvider != nil)
        .accessibilityIdentifier("connectors.enabled.\(provider.rawValue)")
    }
}

#endif
