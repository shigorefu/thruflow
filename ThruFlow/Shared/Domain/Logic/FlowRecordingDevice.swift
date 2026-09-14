import Foundation
import Security

/// Device-only identity. It is deliberately not synchronized or restored onto another device.
nonisolated enum FlowRecordingDevice {
    static let id: String? = {
        let process = ProcessInfo.processInfo
        if process.environment["XCTestConfigurationFilePath"] != nil ||
            process.arguments.contains("--uitesting") || process.arguments.contains("--demo-data") ||
            process.arguments.contains("--onboarding-preview") ||
            process.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" { return "isolated-preview" }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.shigorefu.thruflow.recording-device.v1",
            kSecAttrAccount as String: "device",
            kSecAttrSynchronizable as String: false
        ]
        func read() -> String? {
            var lookup = query
            lookup[kSecReturnData as String] = true
            var result: CFTypeRef?
            guard SecItemCopyMatching(lookup as CFDictionary, &result) == errSecSuccess,
                  let data = result as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        }
        if let existing = read() { return existing }
        let id = UUID().uuidString
        var item = query
        item[kSecValueData as String] = Data(id.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        return status == errSecSuccess ? id : read()
    }()
}
