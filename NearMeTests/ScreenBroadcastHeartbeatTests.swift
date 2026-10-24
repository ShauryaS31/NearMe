import Foundation
import XCTest
@testable import NearMe

@MainActor
final class ScreenBroadcastHeartbeatTests: XCTestCase {
    func testMissingStaleFutureAndInvalidHeartbeatShowOff() {
        let now = Date(timeIntervalSince1970: 100)
        let invalid: [ScreenBroadcastHeartbeat?] = [
            nil,
            ScreenBroadcastHeartbeat(timestamp: 96, frameCount: 2),
            ScreenBroadcastHeartbeat(timestamp: 101, frameCount: 2),
            ScreenBroadcastHeartbeat(timestamp: 100, frameCount: -1),
            ScreenBroadcastHeartbeat(timestamp: .infinity, frameCount: 2)
        ]
        for heartbeat in invalid {
            XCTAssertEqual(SharedScreenBridge.debugLine(heartbeat: heartbeat, now: now), "Screen: off")
        }
        let fresh = ScreenBroadcastHeartbeat(timestamp: 98.5, frameCount: 25)
        XCTAssertEqual(SharedScreenBridge.debugLine(heartbeat: fresh, now: now),
                       "Screen: broadcast on, last update 1 s ago")
        XCTAssertEqual(SharedScreenBridge.debugLine(heartbeat: fresh,
            now: Date(timeIntervalSince1970: 102)), "Screen: off")
    }

    func testHeartbeatOverwritesOnlySmallJSONAndRejectsBrokenData() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("screen-heartbeat.json")
        XCTAssertNil(SharedScreenBridge.read(from: url))
        try SharedScreenBridge.write(ScreenBroadcastHeartbeat(timestamp: 100, frameCount: 1), to: url)
        let latest = ScreenBroadcastHeartbeat(timestamp: 101, frameCount: 50)
        try SharedScreenBridge.write(latest, to: url)
        XCTAssertEqual(SharedScreenBridge.read(from: url), latest)
        let data = try Data(contentsOf: url)
        XCTAssertLessThan(data.count, 1_024)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(object.keys), Set(["timestamp", "frameCount"]))
        let filenames = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertEqual(filenames, ["screen-heartbeat.json"])
        try Data("broken".utf8).write(to: url)
        XCTAssertNil(SharedScreenBridge.read(from: url))
        try Data(repeating: 32, count: 1_025).write(to: url)
        XCTAssertNil(SharedScreenBridge.read(from: url))
    }
}
