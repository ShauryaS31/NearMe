// Adapted from a prior prototype, used with permission.

import Foundation
import Combine

@MainActor
final class VideoPracticeViewModel: ObservableObject {
    @Published private(set) var step: VideoPracticeStep = .tapSearch
    @Published private(set) var isComplete = false
    @Published private(set) var highlightRepeatRevision = 0
    @Published var song = "Tum Hi Ho"
    var onStepAdvanced: (() -> Void)?

    var currentCaption: String { isComplete ? VideoPracticeStep.completionLine : step.caption }

    func repeatHighlight() { highlightRepeatRevision += 1 }

    func openSearch() { advance(from: .tapSearch, to: .typeSong) }
    func enterSong() { advance(from: .typeSong, to: .submitSearch) }
    func search() { advance(from: .submitSearch, to: .selectResult) }
    func selectFirstResult() { advance(from: .selectResult, to: .tapPlay) }

    func play() {
        guard step == .tapPlay, !isComplete else { return }
        isComplete = true
        onStepAdvanced?()
    }

    private func advance(from expected: VideoPracticeStep, to next: VideoPracticeStep) {
        guard step == expected, !isComplete else { return }
        step = next
        onStepAdvanced?()
    }
}
