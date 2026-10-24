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
            (.showingResults, PracticeScreen.ResultsLabels.tripOption(1))
        ]
        for (step, label) in labels {
            XCTAssertTrue(step.caption(origin: "Central", destination: "Town Hall").contains("Tap \(label)") ||
                          step.caption(origin: "Central", destination: "Town Hall").contains("tap \(label)"))
        }
    }

    func testCaptionMatchesPracticeStateAndNextStepForPrefetch() {
        let intent = JourneyIntent(intent: .planJourney, destination: "Town Hall", origin: "Central", mode: nil)
        let practice = TripPlannerPracticeViewModel(intent: intent)
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
}
