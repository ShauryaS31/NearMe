import XCTest
@testable import NearMe

@MainActor
final class PlaceNormalizationTests: XCTestCase {
    func testPlaceholdersAreMissingAcrossCleanupFillAndSuggestions() async throws {
        for placeholder in ["nil", "null", "none", "unknown", "n/a", "-", ""] {
            for text in [placeholder, " \n\(placeholder.uppercased())\t "] {
                XCTAssertNil(PlaceNormalization.normalize(text), text)
                XCTAssertTrue(PracticeVocabulary.closestPlaces(to: text).isEmpty, text)
                for slot in [MissingSlot.origin, .destination] {
                    let answer = try await KeywordFallbackBrain().extractPlace(from: text, for: slot)
                    XCTAssertNil(answer.value, text)
                    let intent = JourneyIntent.empty.filling(slot, with: text)
                    XCTAssertNil(intent.origin, text)
                    XCTAssertNil(intent.destination, text)
                }
                let intent = try await KeywordFallbackBrain().extractIntent(from: "from \(text) to Town Hall")
                XCTAssertNil(intent.value.origin, text)
                XCTAssertEqual(intent.value.destination, "Town Hall")
                let raw = JourneyIntent(intent: .planJourney, destination: "Town Hall", origin: text, mode: nil)
                XCTAssertEqual(raw.firstMissingSlot, .origin)
            }
        }
    }

    func testOrdinaryPlaceSpellingIsPreserved() {
        XCTAssertNil(PlaceNormalization.normalize(nil))
        for place in ["Newtown", "Holsworth", "Unknown Bay", "None Such Place", "Nil Street"] {
            XCTAssertEqual(PlaceNormalization.normalize(" \(place)\n"), place)
        }
    }
}
