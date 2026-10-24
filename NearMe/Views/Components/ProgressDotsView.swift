// Adapted from a prior prototype, used with permission.

import SwiftUI

struct ProgressDotsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                Image(systemName: "hourglass")
            } else {
                ProgressView()
            }
        }
        .tint(TTColor.accent)
        .accessibilityHidden(true)
    }
}
