//
//  EmojiValidation.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/08.
//

import Foundation

enum EmojiValidation {
    static func normalizedSingleEmoji(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let firstCharacter = trimmed.first,
              isEmoji(firstCharacter) else {
            return nil
        }

        return String(firstCharacter)
    }

    static func isEmoji(_ character: Character) -> Bool {
        let scalars = Array(character.unicodeScalars)
        guard !scalars.isEmpty else { return false }

        let hasEmojiPresentation = scalars.contains { $0.properties.isEmojiPresentation }
        let hasVariationSelector = scalars.contains { $0.value == 0xFE0F }
        let hasJoiner = scalars.contains { $0.value == 0x200D }
        let hasEmojiModifier = scalars.contains {
            $0.properties.isEmojiModifier || $0.properties.isEmojiModifierBase
        }
        let isFlag = scalars.count == 2 && scalars.allSatisfy {
            (0x1F1E6...0x1F1FF).contains($0.value)
        }
        let isKeycap = scalars.contains { $0.value == 0x20E3 }

        return hasEmojiPresentation ||
            hasVariationSelector ||
            hasJoiner ||
            hasEmojiModifier ||
            isFlag ||
            isKeycap
    }
}
