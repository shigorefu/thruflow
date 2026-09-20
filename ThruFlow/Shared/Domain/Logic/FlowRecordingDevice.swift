import Foundation
import Security
import LocalAuthentication

/// Device-only identity. It is deliberately not synchronized or restored onto another device.
nonisolated enum FlowRecordingDevice {
    static var id: String? { resolve(allowInteraction: false) }

    static func resolve(allowInteraction: Bool) -> String? {
        let process = ProcessInfo.processInfo
        if process.environment["XCTestConfigurationFilePath"] != nil ||
            process.arguments.contains("--uitesting") || process.arguments.contains("--demo-data") ||
            process.arguments.contains("--onboarding-preview") ||
            process.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" { return "isolated-preview" }
        let context = LAContext()
        context.interactionNotAllowed = !allowInteraction
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.shigorefu.thruflow.recording-device.v1",
            kSecAttrAccount as String: "device",
            kSecAttrSynchronizable as String: false,
            kSecUseAuthenticationContext as String: context
        ]
        var readStatus = errSecSuccess
        func read() -> String? {
            var lookup = query
            lookup[kSecReturnData as String] = true
            var result: CFTypeRef?
            readStatus = SecItemCopyMatching(lookup as CFDictionary, &result)
            guard readStatus == errSecSuccess,
                  let data = result as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        }
        if let existing = read() { return existing }
        // A locked/inaccessible existing identity is not a missing identity.
        guard readStatus == errSecItemNotFound else { return nil }
        let id = UUID().uuidString
        var item = query
        item[kSecValueData as String] = Data(id.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        return status == errSecSuccess ? id : read()
    }
}
