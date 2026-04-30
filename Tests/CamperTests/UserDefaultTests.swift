import Combine
import Foundation
import XCTest

@testable import Camper

private struct UserPreferences: Codable, Equatable {
    var theme: String
    var notifications: Bool
}

final class UserDefaultTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "camper.tests.userdefault.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: - UserDefault

    func testReadsDefaultWhenStoreEmpty() {
        let wrapper = UserDefault<Int>(key: "missing", container: defaults, defaultValue: 7)
        XCTAssertEqual(wrapper.wrappedValue, 7)
    }

    func testWriteAndReadRoundTrip() {
        let wrapper = UserDefault<Int>(key: "counter", container: defaults, defaultValue: 0)
        wrapper.wrappedValue = 42
        XCTAssertEqual(wrapper.wrappedValue, 42)

        let other = UserDefault<Int>(key: "counter", container: defaults, defaultValue: 0)
        XCTAssertEqual(other.wrappedValue, 42, "value must persist across wrapper instances")
    }

    func testNilOptionalRemovesValue() {
        let wrapper = UserDefault<String?>(key: "nick", container: defaults, defaultValue: nil)
        wrapper.wrappedValue = "Trail"
        XCTAssertEqual(wrapper.wrappedValue, "Trail")

        wrapper.wrappedValue = nil
        XCTAssertNil(defaults.object(forKey: "nick"), "setting nil must clear the underlying key")
    }

    func testInitWithWrappedValueShorthand() {
        @UserDefault("greeting", store: defaults) var greeting: String = "hi"
        XCTAssertEqual(greeting, "hi")
        greeting = "hello"
        XCTAssertEqual(greeting, "hello")

        @UserDefault("greeting", store: defaults) var greetingReadback: String = "fallback"
        XCTAssertEqual(greetingReadback, "hello")
    }

    func testProjectedPublisherEmitsOnWrite() {
        let wrapper = UserDefault<Int>(key: "events", container: defaults, defaultValue: 0)
        var received: [Int] = []
        let cancellable = wrapper.projectedValue.sink { received.append($0) }

        wrapper.wrappedValue = 1
        wrapper.wrappedValue = 2
        wrapper.wrappedValue = 3

        // CurrentValueSubject sends initial value too.
        XCTAssertEqual(received, [0, 1, 2, 3])
        cancellable.cancel()
    }

    func testTransformerRoundTrip() {
        let transformer = ReversingStringTransformer()
        let wrapper = UserDefault<String>(key: "transformed", container: defaults, transformer: transformer, defaultValue: "default")

        wrapper.wrappedValue = "hello"
        XCTAssertEqual(wrapper.wrappedValue, "hello")

        let stored = defaults.data(forKey: "transformed")
        XCTAssertNotNil(stored, "transformer must store Data, not the raw value")
        XCTAssertEqual(String(data: stored ?? Data(), encoding: .utf8), "olleh", "raw bytes must reflect the forward transformation")
    }

    // MARK: - CodableUserDefault

    func testCodableReadsDefaultWhenStoreEmpty() {
        let initial = UserPreferences(theme: "dark", notifications: false)
        let wrapper = CodableUserDefault<UserPreferences>(key: "prefs", container: defaults, defaultValue: initial)
        XCTAssertEqual(wrapper.wrappedValue, initial)
    }

    func testCodableWriteAndReadRoundTrip() {
        let wrapper = CodableUserDefault<UserPreferences>(
            key: "prefs",
            container: defaults,
            defaultValue: UserPreferences(theme: "light", notifications: false)
        )

        let updated = UserPreferences(theme: "dark", notifications: true)
        wrapper.wrappedValue = updated

        let other = CodableUserDefault<UserPreferences>(
            key: "prefs",
            container: defaults,
            defaultValue: UserPreferences(theme: "light", notifications: false)
        )
        XCTAssertEqual(other.wrappedValue, updated)
    }

    func testCodableNilOptionalRemovesValue() {
        let wrapper = CodableUserDefault<UserPreferences?>(
            key: "optional.prefs",
            container: defaults,
            defaultValue: nil
        )
        wrapper.wrappedValue = UserPreferences(theme: "x", notifications: true)
        XCTAssertNotNil(defaults.object(forKey: "optional.prefs"))

        wrapper.wrappedValue = nil
        XCTAssertNil(defaults.object(forKey: "optional.prefs"))
    }

    func testCodableFallsBackToDefaultOnGarbageData() {
        defaults.set(Data("not json".utf8), forKey: "broken")
        let wrapper = CodableUserDefault<UserPreferences>(
            key: "broken",
            container: defaults,
            defaultValue: UserPreferences(theme: "fallback", notifications: false)
        )
        XCTAssertEqual(wrapper.wrappedValue.theme, "fallback")
    }

    func testCodableInitWithWrappedValueShorthand() {
        @CodableUserDefault("prefs.shorthand", store: defaults) var prefs: UserPreferences = UserPreferences(theme: "system", notifications: true)
        prefs = UserPreferences(theme: "dark", notifications: false)

        @CodableUserDefault("prefs.shorthand", store: defaults) var readback: UserPreferences = UserPreferences(theme: "system", notifications: true)
        XCTAssertEqual(readback, UserPreferences(theme: "dark", notifications: false))
    }
}

// MARK: - Test transformer

private final class ReversingStringTransformer: ValueTransformer {
    override class func transformedValueClass() -> AnyClass { NSData.self }
    override class func allowsReverseTransformation() -> Bool { true }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let string = value as? String else { return nil }
        return Data(String(string.reversed()).utf8)
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data, let string = String(data: data, encoding: .utf8) else { return nil }
        return String(string.reversed())
    }
}
