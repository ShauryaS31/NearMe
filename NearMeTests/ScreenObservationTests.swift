import Foundation
import XCTest
@testable import NearMe

@MainActor
final class ScreenObservationTests: XCTestCase {
    private func snapshot(_ texts: [String], at time: TimeInterval = 100) -> ScreenSnapshot {
        let lines: [ScreenSnapshot.Line] = texts.enumerated().map { index, text in
            let y = min(0.9, 0.2 + Double(index) * 0.04)
            return ScreenSnapshot.Line(text: text, box: ScreenSnapshot.Box(x: 0.1, y: y, width: 0.5, height: 0.03))
        }
        return ScreenSnapshot(timestamp: time, lines: lines)
    }

    func testInterpreterSequencePromptOtherAppAndThinEvidence() {
        let cases: [([String], ScreenReading.Page)] = [
            (["Home", "Shorts", "Subscriptions", "Search"], .home),
            (["Search YouTube", "space", "return"], .searchOpen),
            (["YouTube", "Home", "Tum Hi Ho", "10M views", "2 years ago"], .results),
            (["Subscribe", "Share", "Comments", "Up next"], .watching),
            (["Home", "Shorts", "Sign in", "Not now"], .prompt),
            (["WhatsApp", "Chats", "Updates", "Calls"], .otherApp),
            (["Settings", "General"], .otherApp),
            ([], .unknown), (["Home"], .unknown), (["10:30"], .unknown)
        ]
        for (texts, expected) in cases {
            let reading = ScreenInterpreter.read(snapshot(texts), guideID: "youtube_play_song", song: "Tum Hi Ho")
            XCTAssertEqual(reading.page, expected, texts.joined(separator: ","))
            if expected == .otherApp { XCTAssertEqual(reading.app, .otherApp) }
        }
        let single = ScreenInterpreter.read(snapshot(["Home"]), guideID: "youtube_play_song", song: nil)
        let multiple = ScreenInterpreter.read(snapshot(["Home", "Shorts", "You"]), guideID: "youtube_play_song", song: nil)
        XCTAssertLessThan(single.confidence, multiple.confidence)
        XCTAssertEqual(single.evidence, ["Home"])
        XCTAssertEqual(ScreenInterpreter.read(snapshot(["Home", "Shorts"]), guideID: "another_guide", song: nil).page, .unknown)
        XCTAssertEqual(ScreenInterpreter.read(snapshot(["You said Home and Shorts"]), guideID: "youtube_play_song", song: nil).page, .unknown)
        XCTAssertEqual(ScreenInterpreter.read(snapshot(["Home", "Shorts", "Chats", "WhatsApp"]), guideID: "youtube_play_song", song: nil).app, .unknown)
    }

    func testDoneAndElapsedTimeCannotAdvanceHomeButFreshChangedPageCan() throws {
        var loop = ScreenCoachLoop()
        let home = snapshot(["Home", "Shorts", "Search"])
        let first = loop.update(snapshot: home, guideID: "youtube_play_song", song: "Tum Hi Ho", now: 100)
        XCTAssertEqual(first?.stepIndex, 1)
        XCTAssertNil(loop.update(snapshot: home, guideID: "youtube_play_song", song: "Tum Hi Ho", now: 101))
        let done = loop.update(snapshot: home, guideID: "youtube_play_song", song: "Tum Hi Ho", now: 101, recheck: true)
        XCTAssertEqual(done?.stepIndex, 1)
        XCTAssertEqual(done?.text, first?.text)
        let search = snapshot(["Search YouTube", "space", "return"], at: 102)
        let next = try XCTUnwrap(loop.update(snapshot: search, guideID: "youtube_play_song", song: "Tum Hi Ho", now: 102))
        XCTAssertEqual(next.stepIndex, 2)
        XCTAssertTrue(next.text.contains("Tum Hi Ho"))
        XCTAssertFalse(next.activityText.contains("Tum Hi Ho"))
        let prompt = snapshot(["Search YouTube", "Sign in", "Not now"], at: 103)
        let interruption = loop.update(snapshot: prompt, guideID: "youtube_play_song", song: "Tum Hi Ho", now: 103)
        XCTAssertNil(interruption?.stepIndex)
        XCTAssertTrue(interruption?.text.contains("\"Not now\"") == true)
        XCTAssertEqual(loop.update(snapshot: snapshot(search.lines.map(\.text), at: 104),
            guideID: "youtube_play_song", song: "Tum Hi Ho", now: 104)?.stepIndex, 2)
        let results = snapshot(["Home", "Shorts", "Tum Hi Ho", "10M views", "2 years ago"], at: 105)
        XCTAssertEqual(loop.update(snapshot: results, guideID: "youtube_play_song", song: "Tum Hi Ho", now: 105)?.stepIndex, 4)
        let watching = snapshot(["Subscribe", "Share", "Comments", "Up next"], at: 106)
        XCTAssertEqual(loop.update(snapshot: watching, guideID: "youtube_play_song", song: "Tum Hi Ho", now: 106)?.text,
                       "It should be playing. Is the song playing?")
        XCTAssertEqual(loop.question, .playback)
    }

    func testObservedSearchBoxAndSongResultPositionAreUsed() throws {
        let left = ScreenSnapshot.Line(text: "Search", box: ScreenSnapshot.Box(x: 0.02, y: 0.02, width: 0.1, height: 0.04))
        let right = ScreenSnapshot.Line(text: "Search", box: ScreenSnapshot.Box(x: 0.85, y: 0.02, width: 0.1, height: 0.04))
        let base = snapshot(["Home", "Shorts"]).lines
        var loop = ScreenCoachLoop()
        XCTAssertEqual(loop.update(snapshot: ScreenSnapshot(timestamp: 100, lines: base + [left]),
            guideID: "youtube_play_song", song: nil, now: 100)?.text, "Tap the magnifying glass at the top left.")
        XCTAssertEqual(loop.update(snapshot: ScreenSnapshot(timestamp: 101, lines: base + [right]),
            guideID: "youtube_play_song", song: nil, now: 101, recheck: true)?.text, "Tap the magnifying glass at the top right.")
        let missing = try XCTUnwrap(loop.update(snapshot: snapshot(["Home", "Shorts"], at: 102),
            guideID: "youtube_play_song", song: nil, now: 102, recheck: true))
        XCTAssertEqual(missing.text, "Tap the magnifying glass at the top right.")
        XCTAssertNil(loop.question)
        let matching = ScreenSnapshot.Line(text: "Tum Hi Ho official", box: ScreenSnapshot.Box(x: 0.1, y: 0.8, width: 0.6, height: 0.04))
        let results = ScreenSnapshot(timestamp: 103, lines: snapshot(["Home", "Shorts", "views", "ago"]).lines + [matching])
        XCTAssertTrue(loop.update(snapshot: results, guideID: "youtube_play_song", song: "Tum Hi Ho", now: 103)?.text.contains("bottom centre") == true)
    }

    func testUnchangedFreshFramesRepromptOnlyEveryFifteenSeconds() {
        var loop = ScreenCoachLoop()
        let texts = ["Home", "Shorts", "Search"]
        _ = loop.update(snapshot: snapshot(texts), guideID: "youtube_play_song", song: nil, now: 100)
        for time in [101.0, 110, 114.9] {
            XCTAssertNil(loop.update(snapshot: snapshot(texts, at: time), guideID: "youtube_play_song", song: nil, now: time))
        }
        let repeated = loop.update(snapshot: snapshot(texts, at: 115), guideID: "youtube_play_song", song: nil, now: 115)
        XCTAssertEqual(repeated?.stepIndex, 1)
        XCTAssertTrue(repeated?.text.hasPrefix("Take your time.") == true)
        XCTAssertNil(loop.update(snapshot: snapshot(texts, at: 115.5), guideID: "youtube_play_song", song: nil, now: 115.5))
        XCTAssertNil(loop.update(snapshot: snapshot(texts, at: 129.9), guideID: "youtube_play_song", song: nil, now: 129.9))
        XCTAssertNotNil(loop.update(snapshot: snapshot(texts, at: 130), guideID: "youtube_play_song", song: nil, now: 130))
    }

    func testKeyboardSearchInstructionRequiresSongInObservedField() {
        var loop = ScreenCoachLoop()
        _ = loop.update(snapshot: snapshot(["Search YouTube", "space", "return"]),
                        guideID: "youtube_play_song", song: "Tum Hi Ho", now: 100)
        let field = ScreenSnapshot.Line(text: "Tum Hi Ho", box: ScreenSnapshot.Box(x: 0.1, y: 0.04, width: 0.7, height: 0.04))
        let keyboard = snapshot(["space", "return", "search"], at: 101).lines
        let typed = ScreenSnapshot(timestamp: 101, lines: [field] + keyboard)
        let value = loop.update(snapshot: typed, guideID: "youtube_play_song", song: "Tum Hi Ho", now: 101)
        XCTAssertEqual(value?.stepIndex, 3)
        XCTAssertEqual(value?.text, "Tap search on the keyboard.")
    }

    func testOtherAppWaitsThreeSecondsAndOffersOnlyOnceEvenAfterNo() {
        var loop = ScreenCoachLoop()
        let texts = ["WhatsApp", "Chats", "Calls"]
        for time in [100.0, 101, 102.9] {
            XCTAssertNil(loop.update(snapshot: snapshot(texts, at: time), guideID: "youtube_play_song", song: nil, now: time))
        }
        XCTAssertEqual(loop.update(snapshot: snapshot(texts, at: 103), guideID: "youtube_play_song", song: nil, now: 103)?.text,
                       "It looks like you've left YouTube. Shall I open it again?")
        XCTAssertEqual(loop.question, .reopen)
        XCTAssertNil(loop.update(snapshot: snapshot(texts, at: 120), guideID: "youtube_play_song", song: nil, now: 120))
        loop.answered()
        XCTAssertNil(loop.update(snapshot: snapshot(texts, at: 140), guideID: "youtube_play_song", song: nil, now: 140))
    }

    func testUnknownQuestionsAndMissingSongAreNotRepeatedAutomatically() {
        var loop = ScreenCoachLoop()
        XCTAssertEqual(loop.update(snapshot: snapshot([]), guideID: "youtube_play_song", song: nil, now: 100)?.text,
                       "I'm not sure what's on your screen. What do you see?")
        XCTAssertNil(loop.update(snapshot: snapshot([], at: 120), guideID: "youtube_play_song", song: nil, now: 120))
        XCTAssertEqual(loop.update(snapshot: snapshot(["Search YouTube"], at: 121), guideID: "youtube_play_song", song: nil, now: 121)?.text,
                       "Which song would you like to play?")
        XCTAssertNil(loop.update(snapshot: snapshot(["Search YouTube"], at: 140), guideID: "youtube_play_song", song: nil, now: 140))
        XCTAssertEqual(loop.update(snapshot: snapshot(["Search YouTube"], at: 141), guideID: "youtube_play_song", song: nil, now: 141, recheck: true)?.text,
                       "Type the song name.")
    }

    func testStaleMissingFutureAndInvalidSnapshotsUseManualModeOnce() {
        var loop = ScreenCoachLoop()
        _ = loop.update(snapshot: snapshot(["Home", "Shorts", "Search"]), guideID: "youtube_play_song", song: nil, now: 100)
        XCTAssertEqual(loop.update(snapshot: snapshot(["Home"]), guideID: "youtube_play_song", song: nil, now: 104)?.text,
                       "I can't see your screen right now.")
        XCTAssertTrue(loop.manual)
        XCTAssertNil(loop.reading)
        XCTAssertNil(loop.update(snapshot: nil, guideID: "youtube_play_song", song: nil, now: 120))
        XCTAssertNil(loop.update(snapshot: snapshot([], at: 200), guideID: "youtube_play_song", song: nil, now: 120))
        XCTAssertFalse(snapshot([], at: .infinity).isFresh(at: 120))
        XCTAssertFalse(snapshot([], at: .nan).isFresh(at: 120))
        XCTAssertTrue(snapshot([]).isFresh(at: 103))
    }

    func testSecretFilterDropsFullLinesLabelsAndFollowingValuesBeforeBounding() {
        let secretLines = ["PIN 1234", "code 12345678", "abcde123", "ab1!cd2?", "AB1234567890", "Card 4111 1111 1111 1111",
                           "Card 4111-1111-1111-1111", "1234567890123", "1234567890123456789", "me@example.test",
                           "+61 412 345 678", "(02) 9876 5432", "Password", "allletters", "Enter passcode", "anothersecret"]
        let filtered = ScreenSecretFilter.filtered(snapshot(secretLines).lines)
        XCTAssertTrue(filtered.isEmpty)
        let afterLimit = String(repeating: "a", count: 90) + " me@example.test"
        XCTAssertTrue(ScreenSecretFilter.filtered(snapshot([afterLimit]).lines).isEmpty)
        let allowed = ["Home", "Shorts", "Search YouTube", "Tum Hi Ho (2013)", "10M views", "2 years ago"]
        XCTAssertEqual(ScreenSecretFilter.filtered(snapshot(allowed).lines).map(\.text), allowed)
        let many = (0..<70).map { _ in String(repeating: "a", count: 100) }
        let bounded = ScreenSecretFilter.filtered(snapshot(many).lines)
        XCTAssertEqual(bounded.count, 60)
        XCTAssertTrue(bounded.allSatisfy { $0.text.count == 80 })
    }

    func testSnapshotAtomicOverwriteStopPauseAndLateWriteUseOneFile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("screen-snapshot.json")
        let writer = ScreenSnapshotWriter(url: url)
        try writer.start()
        XCTAssertNil(SharedScreenBridge.read(from: url))
        try writer.write(snapshot(["Home", "code 1234"]))
        XCTAssertEqual(SharedScreenBridge.read(from: url)?.lines.map(\.text), ["Home"])
        let next = snapshot(["Search YouTube"], at: 101)
        try writer.write(next)
        XCTAssertEqual(SharedScreenBridge.read(from: url), next)
        XCTAssertEqual(AppGroupScreenSnapshotSource(url: url, now: { 101 }).latest(), next)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), ["screen-snapshot.json"])
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        XCTAssertEqual(Set(object.keys), Set(["timestamp", "lines"]))
        for _ in 0..<2 {
            // Both ReplayKit pause and finish call exactly this stop operation.
            try writer.stop()
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
            try writer.write(next)
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.path), "A late write after stop must do nothing")
            try writer.start()
            try writer.write(next)
        }
        try Data("broken".utf8).write(to: url)
        XCTAssertNil(SharedScreenBridge.read(from: url))
        try Data(repeating: 32, count: SharedScreenBridge.maximumBytes + 1).write(to: url)
        XCTAssertNil(SharedScreenBridge.read(from: url))
        try writer.stop()
    }

    func testObserverUsesTextSetsNotTimestampOrLineOrderAndDropsStaleText() {
        let source = FakeScreenSnapshotSource()
        var now = 100.0
        let observer = ScreenObserver(source: source, now: { now })
        source.value = snapshot(["Home", "Shorts"])
        observer.poll()
        XCTAssertTrue(observer.changed)
        XCTAssertEqual(observer.age, 0)
        source.value = snapshot(["Shorts", "Home"], at: 101)
        now = 101
        observer.poll()
        XCTAssertFalse(observer.changed)
        source.value = snapshot(["Search YouTube"], at: 102)
        now = 102
        observer.poll()
        XCTAssertTrue(observer.changed)
        now = 106
        observer.poll()
        XCTAssertFalse(observer.canSee)
        XCTAssertNil(observer.snapshot)
        XCTAssertEqual(observer.age, 4)
        observer.stop()
        XCTAssertNil(observer.age)
    }

    func testHeartbeatRetainsFilteredWordsClearsFailureAndCannotRecreateStoppedFile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("screen-snapshot.json")
        let writer = ScreenSnapshotWriter(url: url)
        try writer.start()
        try writer.write(snapshot(["Home", "Shorts", "123456", "Password", "hidden"]))
        for time in 101...120 { try writer.refresh(at: Double(time)) }
        let refreshed = try XCTUnwrap(SharedScreenBridge.read(from: url))
        XCTAssertEqual(refreshed.timestamp, 120)
        XCTAssertEqual(refreshed.lines.map(\.text), ["Home", "Shorts"])
        try writer.recognitionFailed(at: 121)
        try writer.refresh(at: 122)
        XCTAssertEqual(SharedScreenBridge.read(from: url)?.lines, [])
        try writer.stop()
        try writer.refresh(at: 123)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        try writer.start()
        try writer.refresh(at: 124)
        XCTAssertEqual(SharedScreenBridge.read(from: url)?.lines, [])
    }

    func testEdgeBoxesClampAndSongYearsSurviveWithoutAllowingCodes() throws {
        let edge = ScreenSnapshot.Line(text: "Tum Hi Ho (2013)",
            box: ScreenSnapshot.Box(x: 0.95, y: 0.98, width: 0.2, height: 0.1))
        let line = try XCTUnwrap(ScreenSecretFilter.filtered([edge]).first)
        XCTAssertEqual(line.text, edge.text)
        XCTAssertEqual(line.box.width, 0.05, accuracy: 0.000001)
        XCTAssertEqual(line.box.height, 0.02, accuracy: 0.000001)
        XCTAssertTrue(line.box.isValid)
        for text in ["1234", "12345678", "A1234", "PIN 1234", "code 123456", "abcd1234"] {
            XCTAssertTrue(ScreenSecretFilter.looksSecret(text), text)
        }
        XCTAssertFalse(ScreenSecretFilter.looksSecret("Song title (2013)"))
    }

    func testSourceDeletesAbandonedSnapshotAfterTenSecondsButKeepsFreshFile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("screen-snapshot.json")
        var now = 100.0
        let source = AppGroupScreenSnapshotSource(url: url, now: { now })
        try SharedScreenBridge.write(snapshot(["Home"]), to: url)
        now = 110
        XCTAssertNotNil(source.latest())
        now = 110.1
        XCTAssertNil(source.latest())
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        try SharedScreenBridge.write(snapshot(["Shorts"], at: now), to: url)
        XCTAssertNotNil(source.latest())
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testActiveSceneHoldsExternalWordsButStillDetectsCaptureLossAndResumes() {
        let source = FakeScreenSnapshotSource()
        var now = 100.0
        let observer = ScreenObserver(source: source, now: { now })
        source.value = snapshot(["Subscribe", "Share", "Comments"])
        observer.poll()
        now = 101
        observer.sceneBecameActive()
        now = 120
        source.value = snapshot(["NearMe", "Done"], at: now)
        observer.poll()
        XCTAssertTrue(observer.canSee)
        XCTAssertEqual(observer.snapshot?.lines.map(\.text), ["Subscribe", "Share", "Comments"])
        XCTAssertEqual(observer.observationTime, 101)
        XCTAssertFalse(observer.changed)
        now = 124
        observer.poll()
        XCTAssertFalse(observer.canSee)
        XCTAssertNil(observer.snapshot)
        observer.sceneBecameInactive()
        source.value = snapshot(["Search YouTube"], at: now)
        observer.poll()
        XCTAssertTrue(observer.changed)
        XCTAssertEqual(observer.snapshot?.lines.map(\.text), ["Search YouTube"])
    }

    func testInitialManualModeIsSilentAndActivityNeverAsksAQuestion() {
        var loop = ScreenCoachLoop()
        XCTAssertNil(loop.update(snapshot: nil, guideID: "youtube_play_song", song: nil, now: 100))
        XCTAssertTrue(loop.manual)
        let screens = [["Home", "Shorts"], ["Search YouTube"], ["Subscribe", "Share", "Comments"], ["Sign in", "Allow"], []]
        for texts in screens {
            let value = loop.update(snapshot: snapshot(texts), guideID: "youtube_play_song", song: nil,
                                    now: 100, recheck: true, allowsSongQuestion: false)
            XCTAssertFalse(value?.activityText.contains("?") == true)
            if texts == ["Search YouTube"] { XCTAssertEqual(value?.text, "Type the song name.") }
        }
    }

    #if DEBUG
    func testDebugEvidenceIsBoundedAndOffWhenStale() {
        let screen = snapshot(["YouTube", "Home", "Shorts", "Subscriptions", "You", "Library"])
        let line = ScreenDebugLine.make(snapshot: screen, song: nil, now: 101)
        XCTAssertTrue(line.hasPrefix("Screen: 1s | app knownApp | page home | evidence "))
        let evidence = line.components(separatedBy: " | evidence ").last ?? ""
        XCTAssertLessThanOrEqual(evidence.count, 40)
        XCTAssertLessThanOrEqual(evidence.split(separator: " ").count, 4)
        XCTAssertEqual(ScreenDebugLine.make(snapshot: screen, song: nil, now: 104), "Screen: off")
    }
    #endif
}

nonisolated final class FakeScreenSnapshotSource: ScreenSnapshotSource {
    var value: ScreenSnapshot?
    func latest() -> ScreenSnapshot? { value }
}
