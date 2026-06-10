import Foundation

extension StringProtocol {
    var firstUppercased: String { prefix(1).uppercased() + dropFirst() }
    var firstCapitalized: String { prefix(1).capitalized + dropFirst() }

    var asInputModel: String { self + ".InputModel" }
    var asInputEnum: String { firstCapitalized + "Input" }

    /// `camelCase` → `snake_case` (e.g. `proseStyle` → `prose_style`). Used by
    /// `@SoftCodable` to map property names to JSON/YAML keys.
    var snakeCased: String {
        var result = ""
        for character in self {
            if character.isUppercase {
                result.append("_")
                result.append(Character(character.lowercased()))
            } else {
                result.append(character)
            }
        }
        return result
    }
}
