import Foundation
import Security
import LocalAuthentication

/// Device-only identity. It is deliberately not synchronized or restored onto another device.
nonisolated enum FlowRecordingDevice {
    @MainActor private static var cachedID: String?

    @MainActor static var id: String? { resolve(allowInteraction: false) }

    @MainActor static func resolve(allowInteraction: Bool) -> String? {
        let process = ProcessInfo.processInfo
        #if DEBUG
        if process.arguments.contains("--screenshot-mode") { return "isolated-preview" }
        #endif
        if process.environment["XCTestConfigurationFilePath"] != nil ||
            process.arguments.contains("--uitesting") || process.arguments.contains("--demo-data") ||
            process.arguments.contains("--onboarding-preview") ||
            process.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" { return "isolated-preview" }
        if let cachedID { return cachedID }
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
            readStatus = KeychainPromptPolicy.perform(allowInteraction: allowInteraction) {
                SecItemCopyMatching(lookup as CFDictionary, &result)
            }
            guard readStatus == errSecSuccess,
                  let data = result as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        }
        if let existing = read() {
            cachedID = existing
            return existing
        }
        // A locked/inaccessible existing identity is not a missing identity.
        guard readStatus == errSecItemNotFound else { return nil }
        let id = UUID().uuidString
        var item = query
        item[kSecValueData as String] = Data(id.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = KeychainPromptPolicy.perform(allowInteraction: allowInteraction) {
            SecItemAdd(item as CFDictionary, nil)
        }
        cachedID = status == errSecSuccess ? id : read()
        return cachedID
    }
}

/// The legacy Mac login keychain does not honor LAContext's no-UI setting.
@MainActor
enum KeychainPromptPolicy {
    static func perform(allowInteraction: Bool, _ operation: () -> OSStatus) -> OSStatus {
#if os(macOS)
        guard !allowInteraction else { return operation() }
        var previous = DarwinBoolean(false)
        guard SecKeychainGetUserInteractionAllowed(&previous) == errSecSuccess,
              SecKeychainSetUserInteractionAllowed(false) == errSecSuccess else {
            return errSecInteractionNotAllowed
        }
        defer { SecKeychainSetUserInteractionAllowed(previous.boolValue) }
#endif
        return operation()
    }
}
