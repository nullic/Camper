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

    func testEncodeDecodeRoundTrips() throws {
        let original = SoftSample(name: "Vex", count: 2, tags: ["x"], proseStyle: "lush", note: nil, requiredId: "id1")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SoftSample.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
