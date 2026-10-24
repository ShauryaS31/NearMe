// Adapted from a prior prototype, used with permission.

import Foundation

enum PracticeLabels {
    static let journeyPlanner = "Journey Planner"
    static let chooseOrigin = "Choose origin"
    static let chooseDestination = "Choose destination"
    static let searchDestination = "Search for a destination"
    static let search = "Search"
    static func station(_ destination: String) -> String { "\(destination) Station" }
}

enum PracticeScreen: Equatable {
    case forYou
    case journeyPlanner
    case destinationSearch
    case results
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

    /// The caption NearMe overlays/speaks at this step. `origin`/`destination`
    /// are interpolated in so the walkthrough matches whatever the user
    /// actually said, not just the Central -> Town Hall example.
    func caption(origin: String, destination: String) -> String {
        switch self {
        case .forYouOpened:
            return "You're in Trip planner practice. Tap \(PracticeLabels.journeyPlanner)."
        case .tapFrom:
            return "Now tap \(PracticeLabels.chooseOrigin)."
        case .typeOrigin:
            return "\(origin) is filled in. Tap \(PracticeLabels.chooseDestination)."
        case .tapToAndTypeDestination:
            return "Tap \(PracticeLabels.searchDestination) to fill in \(destination)."
        case .selectingDestination:
            return "Tap \(PracticeLabels.station(destination)) to add it as your destination."
        case .readyToSearch:
            return "Both fields are filled. Tap \(PracticeLabels.search) to see your options."
        case .showingResults:
            return "That's the practice done. In the real app, you'd pick a trip from this list and follow its steps. Anything else you need help with?"
        }
    }

    var next: PracticeStep? {
        let all = PracticeStep.allCases
        guard let index = all.firstIndex(of: self), index + 1 < all.count else { return nil }
        return all[index + 1]
    }
}
