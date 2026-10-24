import Foundation

enum PlannerCallTimeout: Error {
    case exceeded
}

/// Returns at the deadline even if the operation does not acknowledge cancellation.
/// A task group would wait for the cancelled generation before leaving its scope.
@MainActor
enum PlannerCallDeadline {
    static func run<Value: Sendable>(
        timeout: Duration,
        operation: @escaping @MainActor @Sendable () async throws -> Value
    ) async throws -> Value {
        try Task.checkCancellation()
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        let (stream, continuation) = AsyncThrowingStream<Value, Error>.makeStream()
        let work = Task { @MainActor in
            do {
                let value = try await operation()
                try Task.checkCancellation()
                guard clock.now < deadline else { throw PlannerCallTimeout.exceeded }
                continuation.yield(value)
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        let timer = Task { @MainActor in
            do {
                try await clock.sleep(until: deadline)
                continuation.finish(throwing: PlannerCallTimeout.exceeded)
            } catch {
                // The caller cancels this timer after completion or cancellation.
            }
        }
        defer {
            work.cancel()
            timer.cancel()
            continuation.finish()
        }
        var iterator = stream.makeAsyncIterator()
        guard let value = try await iterator.next() else { throw CancellationError() }
        try Task.checkCancellation()
        return value
    }
}
