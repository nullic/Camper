import Foundation

extension StringProtocol {
    var firstUppercased: String { prefix(1).uppercased() + dropFirst() }
    var firstCapitalized: String { prefix(1).capitalized + dropFirst() }

    var asInputModel: String { self + ".InputModel" }
    var asInputEnum: String { firstCapitalized + "Input" }

    /// `camelCase` → `snake_case` (e.g. `proseStyle` → `prose_style`). Used by `@SoftCodable`
    /// to map property names to JSON/YAML keys.
    ///
    /// A run of capitals is one word, not one word per letter: `backendID` → `backend_id`,
    /// `revealsNPCIds` → `reveals_npc_ids`. Spelling each capital as its own word produced keys
    /// like `reveals_n_p_c_ids`, and soft decoding answers a key nobody wrote with the property's
    /// default — so the mismatch cost data rather than throwing.
    ///
    /// Two spellings are still not derivable and want `@SoftKey`: an acronym followed by another
    /// (`requiredPCID` → `required_pc_id`) and a pluralised one (`presentNPCs` → `present_npcs`).
    var snakeCased: String {
        let characters = Array(self)
        var result = ""
        for (index, character) in characters.enumerated() {
            guard character.isUppercase else {
                result.append(character)
                continue
            }
            let previous = index > 0 ? characters[index - 1] : nil
            let next = index + 1 < characters.count ? characters[index + 1] : nil
            let opensWord = previous.map { !$0.isUppercase } ?? false
            let closesRun = (previous?.isUppercase ?? false) && (next?.isLowercase ?? false)
            if opensWord || closesRun {
                result.append("_")
            }
            result.append(Character(character.lowercased()))
        }
        return result
    }
}
