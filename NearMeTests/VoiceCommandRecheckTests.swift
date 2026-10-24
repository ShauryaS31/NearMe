import Foundation
import XCTest
@testable import NearMe

@MainActor
final class VoiceCommandRecheckTests: XCTestCase {
    func testRecheckUsesNewestSnapshotArrivingDuringWait() async throws {
        let source = FakeScreenSnapshotSource()
        var now = 100.0
        let home = ScreenSnapshot(timestamp: now, lines: [])
        source.value = home
        var waits: [TimeInterval] = []
        let observer = ScreenObserver(source: source, now: { now }, recheckWait: { interval in
            waits.append(interval)
            now += interval
            source.value = ScreenSnapshot(timestamp: now, lines: [
                ScreenSnapshot.Line(text: "Search YouTube", box: ScreenSnapshot.Box(x: 0, y: 0, width: 1, height: 0.1))
            ])
        })
        observer.poll()
        let result = try await observer.freshForRecheck()
        XCTAssertEqual(result?.lines.first?.text, "Search YouTube")
        XCTAssertEqual(waits, [0.1])
    }

    func testRecheckDeadlineIsOnePointFiveSecondsAndKeepsNewestUsableSnapshot() async throws {
        let source = FakeScreenSnapshotSource()
        var now = 100.0
        source.value = ScreenSnapshot(timestamp: now, lines: [])
        var waits = 0
        let observer = ScreenObserver(source: source, now: { now }, recheckWait: { interval in
            waits += 1
            now += interval
        })
        observer.poll()
        let result = try await observer.freshForRecheck()
        XCTAssertEqual(waits, 15)
        XCTAssertEqual(now, 101.5, accuracy: 0.0001)
        XCTAssertEqual(result?.timestamp, 100)
        now = 104
        let stale = try await observer.freshForRecheck()
        XCTAssertNil(stale, "A voice recheck must not return stale evidence")
    }

    func testRecheckPreservesExternalObservationWhileNearMeIsForeground() async throws {
        let source = FakeScreenSnapshotSource()
        var now = 100.0
        source.value = ScreenSnapshot(timestamp: now, lines: [])
        var waits = 0
        let observer = ScreenObserver(source: source, now: { now }, recheckWait: { _ in waits += 1 })
        observer.poll()
        observer.sceneBecameActive()
        now = 101
        source.value = ScreenSnapshot(timestamp: now, lines: [])
        let result = try await observer.freshForRecheck()
        XCTAssertEqual(result?.timestamp, 100)
        XCTAssertEqual(waits, 0)
    }
}
