// Adapted from a prior prototype, used with permission.

import Foundation
import Combine

@MainActor
final class TripPlannerPracticeViewModel: ObservableObject {
    @Published private(set) var step: PracticeStep = .forYouOpened
    @Published private(set) var highlightRepeatRevision = 0
    @Published var fromFieldText: String = ""
    @Published var toFieldText: String = ""
    @Published var destinationSearchQuery: String = ""
    @Published var departureDate: Date = Date()

    let intent: JourneyIntent
    var onStepAdvanced: ((PracticeStep) -> Void)?

    init(intent: JourneyIntent) {
        self.intent = intent
    }

    var originDisplayName: String { clean(fromFieldText).isEmpty ? (intent.origin ?? "your starting place") : clean(fromFieldText) }
    var destinationDisplayName: String { clean(destinationSearchQuery).isEmpty ? (intent.destination ?? "your destination") : clean(destinationSearchQuery) }
    var canContinueOrigin: Bool { !clean(fromFieldText).isEmpty }
    var canContinueDestination: Bool { !clean(destinationSearchQuery).isEmpty }
    var canReview: Bool { canContinueOrigin && !clean(toFieldText).isEmpty }

    // Google Maps URLs do not document a departure-time parameter. The selected
    // date remains visible in our review and must be selected again in Maps.
    var transitDirectionsURL: URL? {
        guard canReview else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.google.com"
        components.path = "/maps/dir/"
        components.queryItems = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "origin", value: clean(fromFieldText)),
            URLQueryItem(name: "destination", value: clean(toFieldText)),
            URLQueryItem(name: "travelmode", value: "transit")
        ]
        guard let url = components.url, url.absoluteString.count <= 2048 else { return nil }
        return url
    }

    func editDestination() {
        guard canContinueOrigin else { return }
        destinationSearchQuery = toFieldText
        move(to: .tapToAndTypeDestination)
    }

    func backToPlanner() {
        destinationSearchQuery = toFieldText
        move(to: canReview ? .readyToSearch : .typeOrigin)
    }

    private func clean(_ text: String) -> String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func move(to next: PracticeStep) {
        step = next
        onStepAdvanced?(step)
    }

    var currentCaption: String {
        step.caption(origin: originDisplayName, destination: destinationDisplayName)
    }

    func repeatHighlight() {
        highlightRepeatRevision += 1
    }

    /// Only explicit submission advances a step. Focusing a field never fills it.
    func completeCurrentStep() {
        switch step {
        case .forYouOpened:
            step = .tapFrom
        case .tapFrom:
            guard canContinueOrigin else { return }
            fromFieldText = clean(fromFieldText)
            step = .typeOrigin
        case .typeOrigin:
            guard canContinueOrigin else { return }
            step = .tapToAndTypeDestination
        case .tapToAndTypeDestination:
            guard canContinueDestination else { return }
            destinationSearchQuery = clean(destinationSearchQuery)
            step = .selectingDestination
        case .selectingDestination:
            guard canContinueDestination else { return }
            toFieldText = clean(destinationSearchQuery)
            step = .readyToSearch
        case .readyToSearch:
            guard canReview else { return }
            step = .showingResults
        case .showingResults:
            return // Stay on the journey review until the user opens Maps or leaves.
        }
        onStepAdvanced?(step)
    }
}
