import XCTest
@testable import NearMe

@MainActor
final class PlannerCallDeadlineTests: XCTestCase {
    func testSuccessfulOperationReturnsValue() async throws {
        let value = try await PlannerCallDeadline.run(timeout: .seconds(1)) { 42 }
        XCTAssertEqual(value, 42)
    }

    func testOperationErrorIsPreserved() async {
        do {
            let _: Int = try await PlannerCallDeadline.run(timeout: .seconds(1)) {
                throw TestError.failed
            }
            XCTFail("Expected the operation's error")
        } catch {
            XCTAssertTrue(error is TestError)
        }
    }

    func testDeadlineReturnsWithoutWaitingForCancellationIgnoringOperation() async {
        let started = expectation(description: "Operation started")
        let returned = expectation(description: "Caller returned at deadline")
        var release: CheckedContinuation<Int, Never>?
        let caller = Task { @MainActor in
            do {
                let _ = try await PlannerCallDeadline.run(timeout: .milliseconds(50)) {
                    await withCheckedContinuation { continuation in
                        release = continuation
                        started.fulfill()
                    }
                }
                XCTFail("Expected timeout, not a late value")
            } catch {
                XCTAssertTrue(error is PlannerCallTimeout)
            }
            returned.fulfill()
        }
        await fulfillment(of: [started, returned], timeout: 2)
        // Release even on assertion failure, so this test cannot leave work hanging.
        release?.resume(returning: 99)
        await caller.value
    }

    func testCallerCancellationReturnsWithoutWaitingForOperation() async {
        let started = expectation(description: "Operation started")
        let returned = expectation(description: "Cancelled caller returned")
        var release: CheckedContinuation<Int, Never>?
        let caller = Task { @MainActor in
            do {
                let _ = try await PlannerCallDeadline.run(timeout: .seconds(10)) {
                    await withCheckedContinuation { continuation in
                        release = continuation
                        started.fulfill()
                    }
                }
                XCTFail("Expected cancellation")
            } catch {
                XCTAssertTrue(error is CancellationError)
            }
            returned.fulfill()
        }
        await fulfillment(of: [started], timeout: 2)
        caller.cancel()
        await fulfillment(of: [returned], timeout: 2)
        release?.resume(returning: 99)
        await caller.value
    }
}

private enum TestError: Error {
    case failed
}
