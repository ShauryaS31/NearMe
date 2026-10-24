import XCTest
@testable import NearMe

@MainActor
final class PracticeCaptionTests: XCTestCase {
    func testEveryActionCaptionNamesTheActualControlLabel() {
        let labels: [(PracticeStep, String)] = [
            (.forYouOpened, PracticeScreen.ForYouLabels.journeyPlanner),
            (.tapFrom, PracticeScreen.JourneyPlannerLabels.chooseOrigin),
            (.typeOrigin, PracticeScreen.JourneyPlannerLabels.chooseDestination),
            (.tapToAndTypeDestination, PracticeScreen.DestinationSearchLabels.searchDestination),
            (.selectingDestination, PracticeScreen.DestinationSearchLabels.station("Town Hall")),
            (.readyToSearch, PracticeScreen.JourneyPlannerLabels.search),
            (.showingResults, PracticeScreen.ResultsLabels.openMaps)
        ]
        for (step, label) in labels {
            XCTAssertTrue(step.caption(origin: "Central", destination: "Town Hall").contains("Tap \(label)") ||
                          step.caption(origin: "Central", destination: "Town Hall").contains("tap \(label)"))
        }
    }

    func testCaptionMatchesPracticeStateAndNextStepForPrefetch() {
        let intent = JourneyIntent(intent: .planJourney, destination: "Town Hall", origin: "Central", mode: nil)
        let practice = TripPlannerPracticeViewModel(intent: intent)
        practice.fromFieldText = "Central"
        practice.destinationSearchQuery = "Town Hall"
        for step in PracticeStep.allCases {
            XCTAssertEqual(practice.step, step)
            XCTAssertEqual(practice.currentCaption, step.caption(origin: "Central", destination: "Town Hall"))
            let next = step.next
            practice.completeCurrentStep()
            XCTAssertEqual(practice.step, next ?? .showingResults)
        }
        XCTAssertEqual(practice.fromFieldText, "Central")
        XCTAssertEqual(practice.toFieldText, "Town Hall")
    }

    func testEmptyFieldsNeverAutofillOrAdvance() {
        let practice = TripPlannerPracticeViewModel(intent: JourneyIntent(
            intent: .planJourney, destination: "Central", origin: "Town Hall", mode: nil))
        practice.completeCurrentStep()
        practice.completeCurrentStep()
        XCTAssertEqual(practice.step, .tapFrom)
        XCTAssertEqual(practice.fromFieldText, "")
        XCTAssertEqual(practice.destinationSearchQuery, "")
        practice.fromFieldText = " \n "
        practice.completeCurrentStep()
        XCTAssertEqual(practice.step, .tapFrom)
        practice.fromFieldText = " Town Hall, Sydney "
        practice.completeCurrentStep()
        practice.editDestination()
        practice.completeCurrentStep()
        XCTAssertEqual(practice.step, .tapToAndTypeDestination)
        XCTAssertFalse(practice.canReview)
        XCTAssertNil(practice.transitDirectionsURL)
    }

    func testEditedPlacesAndTimeSurviveReviewAndBacktracking() {
        let practice = TripPlannerPracticeViewModel(intent: JourneyIntent(
            intent: .planJourney, destination: "Original destination", origin: "Original origin", mode: nil))
        practice.completeCurrentStep()
        practice.fromFieldText = "Town Hall, Sydney"
        practice.completeCurrentStep()
        practice.editDestination()
        practice.destinationSearchQuery = "Central, Sydney"
        practice.completeCurrentStep()
        practice.completeCurrentStep()
        let chosenDate = Date(timeIntervalSince1970: 1_800_000_000)
        practice.departureDate = chosenDate
        practice.completeCurrentStep()
        XCTAssertEqual(practice.step, .showingResults)
        XCTAssertTrue(practice.currentCaption.contains("Town Hall, Sydney"))
        XCTAssertTrue(practice.currentCaption.contains("Central, Sydney"))
        XCTAssertFalse(practice.currentCaption.contains("Original"))
        practice.completeCurrentStep()
        XCTAssertEqual(practice.step, .showingResults)
        practice.backToPlanner()
        practice.editDestination()
        practice.destinationSearchQuery = "Unconfirmed edit"
        practice.backToPlanner()
        XCTAssertEqual(practice.destinationSearchQuery, "Central, Sydney")
        XCTAssertEqual(practice.toFieldText, "Central, Sydney")
        XCTAssertEqual(practice.departureDate, chosenDate)
        practice.editDestination()
        practice.destinationSearchQuery = "Parramatta, Sydney"
        practice.completeCurrentStep()
        practice.completeCurrentStep()
        practice.fromFieldText = "Redfern, Sydney"
        practice.completeCurrentStep()
        XCTAssertTrue(practice.currentCaption.contains("Redfern, Sydney"))
        XCTAssertTrue(practice.currentCaption.contains("Parramatta, Sydney"))
        XCTAssertEqual(practice.departureDate, chosenDate)
    }

    func testMapsHandoffEncodesTypedPlacesWithoutInventingTimeSupport() throws {
        let practice = TripPlannerPracticeViewModel(intent: .empty)
        practice.fromFieldText = " Town Hall & George St, Sydney "
        practice.toFieldText = "Caf\u{00E9} Central #2"
        let url = try XCTUnwrap(practice.transitDirectionsURL)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = try XCTUnwrap(components.queryItems)
        XCTAssertEqual(components.host, "www.google.com")
        XCTAssertEqual(components.path, "/maps/dir/")
        XCTAssertEqual(items.first { $0.name == "origin" }?.value, "Town Hall & George St, Sydney")
        XCTAssertEqual(items.first { $0.name == "destination" }?.value, "Caf\u{00E9} Central #2")
        XCTAssertEqual(items.first { $0.name == "travelmode" }?.value, "transit")
        XCTAssertEqual(items.first { $0.name == "api" }?.value, "1")
        XCTAssertEqual(items.count, 4)
        XCTAssertNil(components.fragment)
        practice.fromFieldText = String(repeating: "long ", count: 600)
        XCTAssertNil(practice.transitDirectionsURL)
    }
}
