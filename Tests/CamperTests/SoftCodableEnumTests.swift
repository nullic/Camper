import Camper
import Foundation
import Testing

/// The enum side of `@SoftCodable`, used through the front door so the code it writes has to
/// compile — and asserted on the bytes, because the whole point is what the document reads like.
///
/// The compiler's own synthesised `Codable` spells a payload `_0`, which is why this exists: a
/// format people author by hand cannot have `_0` in it.
@Suite("@SoftCodable · enum")
struct SoftCodableEnumTests {
    @SoftCodable
    struct Fact: Equatable {
        var id: String = ""
        var learns: String = ""
    }

    @SoftCodable
    indirect enum Effect: Equatable {
        case finish
        case establish(Fact)
        case spend(resource: String, amount: Int)
        case onAttempt(String)
        case retry(Effect)
    }

    private func json(_ value: some Encodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try String(decoding: encoder.encode(value), as: UTF8.self)
    }

    private func back<T: Decodable>(_ text: String, as _: T.Type = T.self) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(text.utf8))
    }

    @Test("a case with no value is a bare string, not an empty object")
    func plainCase() throws {
        #expect(try json([Effect.finish]) == #"["finish"]"#)
        #expect(try back(#"["finish"]"#, as: [Effect].self) == [.finish])
    }

    @Test("one value is written directly under the case's name")
    func singleValue() throws {
        let effect = Effect.establish(Fact(id: "fact_log", learns: "The log stops."))
        #expect(try json(effect) == #"{"establish":{"id":"fact_log","learns":"The log stops."}}"#)
        #expect(try back(try json(effect), as: Effect.self) == effect)
    }

    @Test("the case's name is snake_case, like a property's key")
    func snakeCasedName() throws {
        #expect(try json(Effect.onAttempt("talk him round")) == #"{"on_attempt":"talk him round"}"#)
        #expect(try back(#"{"on_attempt":"talk him round"}"#, as: Effect.self) == .onAttempt("talk him round"))
    }

    @Test("two values are written under their own names")
    func labelledValues() throws {
        let effect = Effect.spend(resource: "doom", amount: 1)
        #expect(try json(effect) == #"{"spend":{"amount":1,"resource":"doom"}}"#)
        #expect(try back(try json(effect), as: Effect.self) == effect)
    }

    @Test("a case carrying the enum itself round-trips")
    func recursiveCase() throws {
        let effect = Effect.retry(.establish(Fact(id: "f", learns: "x")))
        #expect(try back(try json(effect), as: Effect.self) == effect)
    }

    @Test("a mixed list keeps every shape")
    func mixedList() throws {
        let effects: [Effect] = [.onAttempt("open the pod"), .establish(Fact(id: "f", learns: "x")), .finish]
        #expect(try back(try json(effects), as: [Effect].self) == effects)
    }

    @Test("a name no case answers to is an error, not a silent drop")
    func unknownCase() throws {
        #expect(throws: (any Error).self) { try back(#""banish""#, as: Effect.self) }
        #expect(throws: (any Error).self) { try back(#"{"banish":1}"#, as: Effect.self) }
        #expect(throws: (any Error).self) { try back(#"{}"#, as: Effect.self) }
    }
}
