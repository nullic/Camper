import Foundation
import SwiftData
import XCTest

@testable import Camper

// MARK: - Test value types

final class CodableSettings: NSObject, Codable {
    let nickname: String
    let counter: Int

    init(nickname: String, counter: Int) {
        self.nickname = nickname
        self.counter = counter
        super.init()
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? CodableSettings else { return false }
        return nickname == other.nickname && counter == other.counter
    }
}

// MARK: - Models

@Model
final class SecureItem {
    @Attribute(.transformable(by: AnySecureCodingValueTransformer<NSURL>.self))
    var url: NSURL

    init(url: NSURL) { self.url = url }
}

@Model
final class JSONItem {
    @Attribute(.transformable(by: JSONValueTransformer<CodableSettings>.self))
    var settings: CodableSettings

    init(settings: CodableSettings) { self.settings = settings }
}

// MARK: - Tests

final class TransformersSwiftDataTests: XCTestCase {
    override class func setUp() {
        AnySecureCodingValueTransformer<NSURL>.register()
        JSONValueTransformer<CodableSettings>.register()
    }

    func testSecureCodingTransformerRoundTrip() throws {
        let schema = Schema([SecureItem.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let original = NSURL(string: "https://example.com/path?q=1")!
        let item = SecureItem(url: original)
        context.insert(item)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<SecureItem>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.url.absoluteString, original.absoluteString)
    }

    func testSecureCodingTransformerReturnsNilOnGarbageData() {
        let transformer = AnySecureCodingValueTransformer<NSURL>()
        let garbage = Data([0xDE, 0xAD, 0xBE, 0xEF])
        XCTAssertNil(transformer.reverseTransformedValue(garbage))
    }

    func testJSONTransformerRoundTrip() throws {
        let schema = Schema([JSONItem.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let settings = CodableSettings(nickname: "Trail Runner", counter: 42)
        let item = JSONItem(settings: settings)
        context.insert(item)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<JSONItem>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.settings.nickname, settings.nickname)
        XCTAssertEqual(fetched.first?.settings.counter, settings.counter)
    }

    func testJSONTransformerReturnsNilOnGarbageData() {
        let transformer = JSONValueTransformer<CodableSettings>()
        let garbage = Data("not json".utf8)
        XCTAssertNil(transformer.reverseTransformedValue(garbage))
    }

    func testJSONTransformerReturnsNilOnWrongInputType() {
        let transformer = JSONValueTransformer<CodableSettings>()
        XCTAssertNil(transformer.transformedValue("not the right type"))
    }

    // MARK: - Cold-start (close-and-reopen) round-trip

    private func makeStoreURL() -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("CamperTransformers-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("store.sqlite")
    }

    private func removeStore(at url: URL) {
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.removeItem(at: dir)
    }

    func testSecureCodingTransformerColdStartRoundTrip() throws {
        let url = makeStoreURL()
        defer { removeStore(at: url) }
        let schema = Schema([SecureItem.self])

        do {
            let config = ModelConfiguration(schema: schema, url: url)
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            let item = SecureItem(url: NSURL(string: "https://example.com/cold")!)
            context.insert(item)
            try context.save()
        }

        do {
            let config = ModelConfiguration(schema: schema, url: url)
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            let fetched = try context.fetch(FetchDescriptor<SecureItem>())
            XCTAssertEqual(fetched.count, 1)
            XCTAssertEqual(fetched.first?.url.absoluteString, "https://example.com/cold")
        }
    }

    func testJSONTransformerColdStartRoundTrip() throws {
        let url = makeStoreURL()
        defer { removeStore(at: url) }
        let schema = Schema([JSONItem.self])

        do {
            let config = ModelConfiguration(schema: schema, url: url)
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            let item = JSONItem(settings: CodableSettings(nickname: "Cold", counter: 7))
            context.insert(item)
            try context.save()
        }

        do {
            let config = ModelConfiguration(schema: schema, url: url)
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            let fetched = try context.fetch(FetchDescriptor<JSONItem>())
            XCTAssertEqual(fetched.count, 1)
            XCTAssertEqual(fetched.first?.settings.nickname, "Cold")
            XCTAssertEqual(fetched.first?.settings.counter, 7)
        }
    }
}
