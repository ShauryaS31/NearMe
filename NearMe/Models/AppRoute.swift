// Adapted from a prior prototype, used with permission.

import Foundation

enum AppRoute: Equatable {
    case welcome
    case goodMorning
    case howItWorks
    case session // voice session + trip planner simulation live inside here, driven by TaskPlannerState
}
