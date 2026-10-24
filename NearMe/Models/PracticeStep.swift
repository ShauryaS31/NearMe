// Adapted from a prior prototype, used with permission.

import Foundation

enum PracticeScreen: Equatable {
    case forYou
    case journeyPlanner
    case destinationSearch
    case results

    // Each screen uses these labels for both its visible content and target anchors.
    enum ForYouLabels {
        static let journeyPlanner = "Journey Planner"
    }

    enum JourneyPlannerLabels {
        static let chooseOrigin = "Choose origin"
        static let chooseDestination = "Choose destination"
        static let search = "Review journey"
    }

    enum DestinationSearchLabels {
        static let searchDestination = "Search for a destination"
        static func station(_ destination: String) -> String { "Use \(destination)" }
    }

    enum ResultsLabels {
        static let openMaps = "Find transit in Google Maps"
    }

    func targetLabels(destination: String) -> [String] {
        switch self {
        case .forYou:
            return [ForYouLabels.journeyPlanner]
        case .journeyPlanner:
            return [JourneyPlannerLabels.chooseOrigin, JourneyPlannerLabels.chooseDestination,
                    JourneyPlannerLabels.search]
        case .destinationSearch:
            return [DestinationSearchLabels.searchDestination, DestinationSearchLabels.station(destination)]
        case .results:
            return [ResultsLabels.openMaps]
        }
    }
}

enum PracticeStep: Equatable, CaseIterable {
    case forYouOpened
    case tapFrom
    case typeOrigin
    case tapToAndTypeDestination
    case selectingDestination
    case readyToSearch
    case showingResults

    var screen: PracticeScreen {
        switch self {
        case .forYouOpened: return .forYou
        case .tapFrom, .typeOrigin, .readyToSearch: return .journeyPlanner
        case .tapToAndTypeDestination, .selectingDestination: return .destinationSearch
        case .showingResults: return .results
        }
    }

    func targetLabel(destination: String) -> String {
        switch self {
        case .forYouOpened: return PracticeScreen.ForYouLabels.journeyPlanner
        case .tapFrom: return PracticeScreen.JourneyPlannerLabels.chooseOrigin
        case .typeOrigin: return PracticeScreen.JourneyPlannerLabels.chooseDestination
        case .tapToAndTypeDestination: return PracticeScreen.DestinationSearchLabels.searchDestination
        case .selectingDestination: return PracticeScreen.DestinationSearchLabels.station(destination)
        case .readyToSearch: return PracticeScreen.JourneyPlannerLabels.search
        case .showingResults: return PracticeScreen.ResultsLabels.openMaps
        }
    }

    /// The caption NearMe displays/speaks at this step. `origin`/`destination`
    /// are interpolated in so the walkthrough matches whatever the user
    /// actually said, not just the Central -> Town Hall example.
    func caption(origin: String, destination: String) -> String {
        switch self {
        case .forYouOpened:
            return "You're in Trip planner practice. Tap \(PracticeScreen.ForYouLabels.journeyPlanner)."
        case .tapFrom:
            return "Tap \(PracticeScreen.JourneyPlannerLabels.chooseOrigin), type your starting place, then tap Continue."
        case .typeOrigin:
            return "Starting from \(origin). Tap \(PracticeScreen.JourneyPlannerLabels.chooseDestination)."
        case .tapToAndTypeDestination:
            return "Tap \(PracticeScreen.DestinationSearchLabels.searchDestination), type where you want to go, then tap Continue."
        case .selectingDestination:
            return "Tap \(PracticeScreen.DestinationSearchLabels.station(destination)) to add it as your destination."
        case .readyToSearch:
            return "From \(origin) to \(destination). Choose your departure date and time, then tap \(PracticeScreen.JourneyPlannerLabels.search)."
        case .showingResults:
            return "Tap \(PracticeScreen.ResultsLabels.openMaps) for routes from \(origin) to \(destination). Set your chosen departure time there too. NearMe has not checked timetables."
        }
    }

    var next: PracticeStep? {
        let all = PracticeStep.allCases
        guard let index = all.firstIndex(of: self), index + 1 < all.count else { return nil }
        return all[index + 1]
    }
}
