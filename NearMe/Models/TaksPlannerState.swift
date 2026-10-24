// Adapted from a prior prototype, used with permission.

import Foundation

enum TaskPlannerState: Equatable {
    /// Orb idle, nothing happening yet (e.g. right after onboarding).
    case idle
    /// NearMe is speaking a prompt/question/confirmation aloud.
    case speaking(String)
    /// Microphone is open, transcribing the user's speech.
    case listening
    /// Capture has stopped; waiting briefly for final recognized words.
    case finishing
    /// Foundation Models is extracting intent / deciding next step.
    case thinking
    /// Transition shown as the trip planner practice opens.
    case openingApp
    /// Inside the (simulated) trip planner walkthrough, at a specific step.
    case guiding(PracticeStep)

    static func == (lhs: TaskPlannerState, rhs: TaskPlannerState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.listening, .listening), (.finishing, .finishing), (.thinking, .thinking),
             (.openingApp, .openingApp):
            return true
        case let (.speaking(a), .speaking(b)):
            return a == b
        case let (.guiding(a), .guiding(b)):
            return a == b
        default:
            return false
        }
    }
}
