import Foundation
import XCTest

@testable import Camper

final class TaskQueueTests: XCTestCase {
    func testReturnsValueFromOperation() async throws {
        let queue = TaskQueue()
        let result = await queue.enqueue { 42 }
        XCTAssertEqual(result, 42)
    }

    func testRethrowsErrorFromOperation() async {
        struct Boom: Error {}
        let queue = TaskQueue()
        do {
            _ = try await queue.enqueue { throw Boom() }
            XCTFail("expected throw")
        } catch is Boom {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testSerialQueueRunsOneAtATime() async {
        let queue = TaskQueue(concurrency: 1)
        let recorder = ActorRecorder()

        await withTaskGroup(of: Void.self) { group in
            for i in 0 ..< 8 {
                group.addTask {
                    await queue.enqueue {
                        await recorder.start(i)
                        try? await Task.sleep(nanoseconds: 5_000_000)
                        await recorder.end(i)
                    }
                }
            }
        }

        let trace = await recorder.trace
        for i in 0 ..< 8 {
            let startIdx = trace.firstIndex(of: .start(i))!
            let endIdx = trace.firstIndex(of: .end(i))!
            XCTAssertLessThan(startIdx, endIdx)
            // No other start should appear between start(i) and end(i) for serial queue.
            let between = trace[(startIdx + 1) ..< endIdx]
            XCTAssertFalse(between.contains(where: { if case .start = $0 { return true } else { return false } }), "serial queue must not interleave; offending span: \(between)")
        }
    }

    func testConcurrentQueueAllowsOverlap() async {
        let queue = TaskQueue(concurrency: 4)
        let tracker = ActiveTracker()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 12 {
                group.addTask {
                    await queue.enqueue {
                        await tracker.enter()
                        try? await Task.sleep(nanoseconds: 5_000_000)
                        await tracker.leave()
                    }
                }
            }
        }

        let peak = await tracker.peak
        XCTAssertGreaterThan(peak, 1, "concurrency=4 must allow overlap (got peak=\(peak))")
        XCTAssertLessThanOrEqual(peak, 4, "concurrency=4 must not exceed 4 concurrent operations")
    }
}

// MARK: - Helpers

private actor ActorRecorder {
    enum Event: Equatable { case start(Int), end(Int) }

    private(set) var trace: [Event] = []
    func start(_ i: Int) { trace.append(.start(i)) }
    func end(_ i: Int) { trace.append(.end(i)) }
}

private actor ActiveTracker {
    private(set) var current = 0
    private(set) var peak = 0

    func enter() {
        current += 1
        if current > peak { peak = current }
    }

    func leave() {
        current -= 1
    }
}
