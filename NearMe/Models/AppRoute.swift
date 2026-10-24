// Adapted from a prior prototype, used with permission.

import Foundation

enum AppRoute: Equatable {
    case welcome
    case goodMorning
    case screenPermission
    case session // voice session + PTV simulation live inside here, driven by TaskPlannerState
}
