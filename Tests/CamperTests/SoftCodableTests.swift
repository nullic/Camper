import Foundation
import XCTest

@testable import Camper

// MARK: - Model

@SoftCodable
struct SoftSample: Equatable {
    var name: String = "default"
    var count: Int = 0
    var tags: [String] = []
    var proseStyle: String = "" // snake_case key: prose_style
    var note: String? // optional → nil when missing
    var requiredId: String // no default → required (snake: required_id)
}

/// A run of capitals is one word, and the two spellings no rule reaches are named outright.
@SoftCodable
struct SoftAcronyms: Equatable {
    var backendID: String = "" // backend_id
    var revealsNPCIds: [String] = [] // reveals_npc_ids
    var aboutNPCId: String? // about_npc_id
    @SoftKey("required_pc_id") var requiredPCID: String? // an acronym next to another
    @SoftKey("present_npcs") var presentNPCs: [String] = [] // a pluralised one
}

/// A format that refuses to migrate: the key must be in the file, and the default is the
/// initializer's alone.
@SoftCodable
struct SoftVersioned: Equatable {
    @SoftRequired var schemaVersion: Int = 3
    var name: String = ""
}

// MARK: - Tests

final class SoftCodableTests: XCTestCase {
    private func decode(_ json: String) throws -> SoftSample {
        try JSONDecoder().decode(SoftSample.self, from: Data(json.utf8))
    }

    func testMissingKeysFallBackToInlineDefaults() throws {
        let sample = try decode(#"{"required_id": "abc", "prose_style": "terse"}"#)
        XCTAssertEqual(sample.requiredId, "abc")
        XCTAssertEqual(sample.proseStyle, "terse") // snake_case key mapped
        XCTAssertEqual(sample.name, "default") // missing → inline default
        XCTAssertEqual(sample.count, 0)
        XCTAssertEqual(sample.tags, [])
        XCTAssertNil(sample.note) // optional missing → nil
    }

    func testPresentKeysOverrideDefaults() throws {
        let sample = try decode(#"{"required_id": "x", "name": "Vex", "count": 3, "tags": ["a","b"], "note": "hi"}"#)
        XCTAssertEqual(sample.name, "Vex")
        XCTAssertEqual(sample.count, 3)
        XCTAssertEqual(sample.tags, ["a", "b"])
        XCTAssertEqual(sample.note, "hi")
    }

    func testMissingRequiredKeyThrows() {
        XCTAssertThrowsError(try decode(#"{"name": "no id here"}"#))
    }

    /// Spelling each capital as its own word gave `reveals_n_p_c_ids`, and soft decoding answers a
    /// key nobody wrote with the property's default — so a wrong key cost data instead of throwing.
    func testAnAcronymIsOneWord() throws {
        let json = #"{"backend_id": "mlx", "reveals_npc_ids": ["npc_1"], "about_npc_id": "npc_2"}"#
        let sample = try JSONDecoder().decode(SoftAcronyms.self, from: Data(json.utf8))
        XCTAssertEqual(sample.backendID, "mlx")
        XCTAssertEqual(sample.revealsNPCIds, ["npc_1"])
        XCTAssertEqual(sample.aboutNPCId, "npc_2")
    }

    /// `requiredPCID` and `presentNPCs` have no case boundary to read, so they say their key.
    func testSoftKeyNamesWhatNoRuleReaches() throws {
        let json = #"{"required_pc_id": "pc_1", "present_npcs": ["npc_1", "npc_2"]}"#
        let sample = try JSONDecoder().decode(SoftAcronyms.self, from: Data(json.utf8))
        XCTAssertEqual(sample.requiredPCID, "pc_1")
        XCTAssertEqual(sample.presentNPCs, ["npc_1", "npc_2"])

        let written = String(decoding: try JSONEncoder().encode(sample), as: UTF8.self)
        XCTAssertTrue(written.contains("required_pc_id"))
        XCTAssertTrue(written.contains("present_npcs"))
    }

    func testSoftRequiredKeepsTheKeyRequiredOnTheWire() throws {
        let present = try JSONDecoder().decode(SoftVersioned.self, from: Data(#"{"schema_version": 2}"#.utf8))
        XCTAssertEqual(present.schemaVersion, 2)
        XCTAssertThrowsError(try JSONDecoder().decode(SoftVersioned.self, from: Data(#"{"name": "x"}"#.utf8)))
        XCTAssertEqual(SoftVersioned(name: "built in code").schemaVersion, 3)
    }

    func testEncodeDecodeRoundTrips() throws {
        let original = SoftSample(name: "Vex", count: 2, tags: ["x"], proseStyle: "lush", note: nil, requiredId: "id1")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SoftSample.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
