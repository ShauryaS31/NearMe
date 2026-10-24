// Adapted from a prior prototype, used with permission.

import Foundation
import Combine

@MainActor
final class TripPlannerPracticeViewModel: ObservableObject {
    @Published private(set) var step: PracticeStep = .forYouOpened
    @Published var fromFieldText: String = ""
    @Published var toFieldText: String = ""
    @Published var destinationSearchQuery: String = ""

    let intent: JourneyIntent
    var onStepAdvanced: ((PracticeStep) -> Void)?

    init(intent: JourneyIntent) {
        self.intent = intent
    }

    var originDisplayName: String { intent.origin ?? "Origin" }
    var destinationDisplayName: String { intent.destination ?? "Destination" }

    var currentCaption: String {
        step.caption(origin: originDisplayName, destination: destinationDisplayName)
    }

    /// Called by whichever simulated trip planner control the current step tells the
    /// user to tap. Advances to the next step and updates any field text
    /// that step is responsible for filling in.
    func completeCurrentStep() {
        switch step {
        case .forYouOpened:
            step = .tapFrom
        case .tapFrom:
            fromFieldText = originDisplayName
            step = .typeOrigin
        case .typeOrigin:
            step = .tapToAndTypeDestination
        case .tapToAndTypeDestination:
            destinationSearchQuery = destinationDisplayName
            step = .selectingDestination
        case .selectingDestination:
            toFieldText = destinationDisplayName
            step = .readyToSearch
        case .readyToSearch:
            step = .showingResults
        case .showingResults:
            return // terminal — "anything else?" is handled by TaskPlannerEngine
        }
        onStepAdvanced?(step)
    }
}
