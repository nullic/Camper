import Camper
import Foundation

@SoftCodable
public struct Boundaries: Sendable, Hashable {
    public var rating: String = ""
    public var avoid: [String] = []
    public var note: String?
    @SoftRequired public var schemaVersion: Int = 3
    @SoftKey("reveals_npc_ids") public var revealsNPCIds: [String] = []
    @SoftIgnore public var isDirty: Bool = false
}

@SoftCodable
public struct Fact: Sendable, Equatable {
    public var id: String = ""
    public var learns: String = ""
}

/// A sum type in a document people author by hand. The case's snake_case name is the key and
/// its value sits directly under it; a case with no value is a bare string, so a mixed list
/// stays readable.
///
/// It stands here because the compiler's own synthesised `Codable` spells a payload `_0` —
/// legal, unreadable, and the reason this branch of the macro exists. A payload type declared
/// beside the enum (`Fact`) is the other reason: the coder is generated as members, because an
/// extension is not lexically inside the enclosing scope and would not resolve it.
@SoftCodable
public enum Effect: Sendable, Equatable {
    case finish // finish
    case establish(Fact) // establish: {id: …, learns: …}
    case inflict(String) // inflict: exhausted
    case spend(resource: String, amount: Int) // spend: {resource: doom, amount: 1}
}

/// Two values must be labelled — each is written under its own name, and an unlabelled pair has
/// none. `case spend(String, Int)` is refused with a diagnostic rather than falling back to
/// `_0` / `_1`, the way `@StringRepresentable` refuses a second value rather than dropping it.
@SoftCodable
public indirect enum Then: Sendable, Equatable {
    case just([Effect])
    case again(Then)
}

func checkSoftCodable() {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]

    let effects: [Effect] = [
        .finish,
        .establish(Fact(id: "fact_log", learns: "The log stops on the 14th.")),
        .spend(resource: "doom", amount: 1),
    ]
    // ["finish",{"establish":{"id":"fact_log","learns":"The log stops on the 14th."}},…]
    guard let written = try? encoder.encode(effects),
          let read = try? JSONDecoder().decode([Effect].self, from: written)
    else { return }
    assert(read == effects)

    // A name no case answers to is an error, not a silent drop — soft decoding is a struct's
    // property falling back to its default, and a sum type has nothing to fall back to.
    assert((try? JSONDecoder().decode(Effect.self, from: Data(#""banish""#.utf8))) == nil)

    let nested = Then.again(.just(effects))
    guard let written = try? encoder.encode(nested),
          let read = try? JSONDecoder().decode(Then.self, from: written)
    else { return }
    assert(read == nested)
}
