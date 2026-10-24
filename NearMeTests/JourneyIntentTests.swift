// Adapted from a prior prototype, used with permission.

import XCTest
@testable import NearMe

final class JourneyIntentTests: XCTestCase {
    func testFirstMissingSlotReturnsOriginWhenEmpty() {
        let intent = JourneyIntent(intent: .planJourney, destination: "Melbourne Central", origin: nil, mode: nil)
        XCTAssertEqual(intent.firstMissingSlot, .origin)
    }

    func testFirstMissingSlotReturnsDestinationWhenOriginKnown() {
        let intent = JourneyIntent(intent: .planJourney, destination: nil, origin: "Box Hill", mode: nil)
        XCTAssertEqual(intent.firstMissingSlot, .destination)
    }

    func testFirstMissingSlotIsNilWhenFullySpecified() {
        let intent = JourneyIntent(intent: .planJourney, destination: "Melbourne Central", origin: "Box Hill", mode: "train")
        XCTAssertNil(intent.firstMissingSlot)
    }

    func testFillingSlotSetsCorrectField() {
        let intent = JourneyIntent(intent: .planJourney, destination: "Melbourne Central", origin: nil, mode: nil)
        let filled = intent.filling(.origin, with: "Box Hill")
        XCTAssertEqual(filled.origin, "Box Hill")
        XCTAssertEqual(filled.destination, "Melbourne Central")
    }
}
