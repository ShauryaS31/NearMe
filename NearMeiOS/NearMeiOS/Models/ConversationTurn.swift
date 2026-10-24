// Adapted from a prior prototype, used with permission.

import Foundation

struct ConversationTurn: Identifiable, Equatable {
    enum Speaker: Equatable {
        case nearme
        case user
    }

    let id = UUID()
    let speaker: Speaker
    let text: String
    let timestamp = Date()
}
