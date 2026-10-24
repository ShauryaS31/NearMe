import XCTest
@testable import NearMe

@MainActor
final class PracticeCaptionTests: XCTestCase {
    func testEveryActionCaptionNamesTheActualControlLabel() {
        let labels: [(PracticeStep, String)] = [
            (.forYouOpened, PracticeLabels.journeyPlanner),
            (.tapFrom, PracticeLabels.chooseOrigin),
            (.typeOrigin, PracticeLabels.chooseDestination),
            (.tapToAndTypeDestination, PracticeLabels.searchDestination),
            (.selectingDestination, PracticeLabels.station("Town Hall")),
            (.readyToSearch, PracticeLabels.search)
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
