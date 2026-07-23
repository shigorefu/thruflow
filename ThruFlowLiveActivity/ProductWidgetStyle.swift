import SwiftUI

extension Color {
    init(productHex: String) {
        let normalized = productHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let value = UInt64(normalized, radix: 16) ?? 0x007AFF
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
