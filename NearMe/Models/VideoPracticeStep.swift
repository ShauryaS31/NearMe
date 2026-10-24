// Adapted from a prior prototype, used with permission.

import Foundation

enum VideoPracticeScreen: Equatable {
    case home, search, results, video

    enum Labels {
        static let search = "Search"
        static let song = "Song"
        static let play = "Play"
        static func result(_ number: Int) -> String { "Example video \(number)" }
    }

    var targetLabels: [String] {
        switch self {
        case .home: return [Labels.search]
        case .search: return [Labels.song, Labels.search]
        case .results: return (1...3).map { Labels.result($0) }
        case .video: return [Labels.play]
        }
    }
}

enum VideoPracticeStep: CaseIterable, Hashable {
    case tapSearch, typeSong, submitSearch, selectResult, tapPlay

    static let completionLine = "That's the practice done. In the real app you'd do the same steps."

    var screen: VideoPracticeScreen {
        switch self {
        case .tapSearch: return .home
        case .typeSong, .submitSearch: return .search
        case .selectResult: return .results
        case .tapPlay: return .video
        }
    }

    var targetLabel: String {
        switch self {
        case .tapSearch, .submitSearch: return VideoPracticeScreen.Labels.search
        case .typeSong: return VideoPracticeScreen.Labels.song
        case .selectResult: return VideoPracticeScreen.Labels.result(1)
        case .tapPlay: return VideoPracticeScreen.Labels.play
        }
    }

    var caption: String {
        switch self {
        case .tapSearch: return "You're in Video app practice. Tap Search at the top right."
        case .typeSong: return "Tap Song to type a song name. Tum Hi Ho is filled in as a suggestion."
        case .submitSearch: return "Tap Search to find example videos."
        case .selectResult: return "Tap Example video 1, the first result."
        case .tapPlay: return "Tap Play to practise starting the video."
        }
    }
}
