import XCTest

@testable import Camper

final class LazyAtomicTests: XCTestCase {
    func testWrappedValueInitEvaluatesOnce() {
        var callCount = 0
        let make: () -> Int = {
            callCount += 1
            return 42
        }

        let lazyValue = LazyAtomic<Int>()
        lazyValue.initializer = make

        XCTAssertEqual(lazyValue.wrappedValue, 42)
        XCTAssertEqual(lazyValue.wrappedValue, 42)
        XCTAssertEqual(callCount, 1)
    }

    func testInitWithWrappedValueAutoclosure() {
        var callCount = 0
        func makeValue() -> String {
            callCount += 1
            return "computed"
        }

        let lazyValue = LazyAtomic<String>(wrappedValue: makeValue())
        XCTAssertEqual(callCount, 0, "autoclosure must not run before first read")

        XCTAssertEqual(lazyValue.wrappedValue, "computed")
        XCTAssertEqual(lazyValue.wrappedValue, "computed")
        XCTAssertEqual(callCount, 1)
    }

    func testSetWrappedValueOverridesInitializer() {
        let lazyValue = LazyAtomic<Int>(wrappedValue: 1)
        lazyValue.wrappedValue = 99
        XCTAssertEqual(lazyValue.wrappedValue, 99)
    }

    func testReplacingInitializerResetsValue() {
        let lazyValue = LazyAtomic<Int>(wrappedValue: 1)
        XCTAssertEqual(lazyValue.wrappedValue, 1)

        lazyValue.initializer = { 2 }
        XCTAssertEqual(lazyValue.wrappedValue, 2)
    }

    func testConcurrentReadsInitializeOnce() {
        let counter = LockedCounter()
        let lazyValue = LazyAtomic<Int>(wrappedValue: counter.incrementAndGet())

        let group = DispatchGroup()
        let queue = DispatchQueue(label: "lazy.atomic.test", attributes: .concurrent)

        for _ in 0 ..< 100 {
            group.enter()
            queue.async {
                _ = lazyValue.wrappedValue
                group.leave()
            }
        }

        group.wait()
        XCTAssertEqual(counter.value, 1, "initializer must run exactly once across concurrent readers")
    }
}

private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = 0

    var value: Int {
        lock.lock(); defer { lock.unlock() }
        return _value
    }

    func incrementAndGet() -> Int {
        lock.lock(); defer { lock.unlock() }
        _value += 1
        return _value
    }
}
