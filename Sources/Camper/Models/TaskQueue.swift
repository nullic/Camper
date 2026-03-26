import Foundation

public actor TaskQueue {
    private let concurrency: Int
    private var running: Int = 0
    private var queue: [CheckedContinuation<Void, Never>] = []

    public init(concurrency: Int = 1) {
        assert(concurrency >= 1)
        self.concurrency = concurrency
    }

    public func enqueue<T>(operation: @Sendable () async throws -> T) async rethrows -> T where T: Sendable {
        await withCheckedContinuation { continuation in
            queue.append(continuation)
            tryRunEnqueued()
        }

        defer {
            running -= 1
            tryRunEnqueued()
        }

        return try await operation()
    }

    private func tryRunEnqueued() {
        guard !queue.isEmpty else { return }
        guard running < concurrency else { return }

        running += 1
        let continuation = queue.removeFirst()
        continuation.resume()
    }
}
