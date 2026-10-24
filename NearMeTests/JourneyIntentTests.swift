// Adapted from a prior prototype, used with permission.

import XCTest
@testable import NearMe

final class JourneyIntentTests: XCTestCase {
    func testFirstMissingSlotReturnsOriginWhenEmpty() {
        let intent = JourneyIntent(intent: .planJourney, destination: "Town Hall", origin: nil, mode: nil)
        XCTAssertEqual(intent.firstMissingSlot, .origin)
    }

    func testFirstMissingSlotReturnsDestinationWhenOriginKnown() {
        let intent = JourneyIntent(intent: .planJourney, destination: nil, origin: "Central", mode: nil)
        XCTAssertEqual(intent.firstMissingSlot, .destination)
    }

    func testFirstMissingSlotIsNilWhenFullySpecified() {
        let intent = JourneyIntent(intent: .planJourney, destination: "Town Hall", origin: "Central", mode: "train")
        XCTAssertNil(intent.firstMissingSlot)
    }

    func testFillingSlotSetsCorrectField() {
        let intent = JourneyIntent(intent: .planJourney, destination: "Town Hall", origin: nil, mode: nil)
        let filled = intent.filling(.origin, with: "Central")
        XCTAssertEqual(filled.origin, "Central")
        XCTAssertEqual(filled.destination, "Town Hall")
    }
}
