// Adapted from a prior prototype, used with permission.

import SwiftUI

struct OpeningPTVView: View {
    let confirmationText: String

    var body: some View {
        ScreenScaffold {
            VStack(spacing: TTSpacing.xl) {
                Spacer(minLength: TTSpacing.xxl)

                Text(confirmationText)
                    .font(TTFont.title())
                    .foregroundStyle(TTColor.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: TTSpacing.md) {
                    Text("OPENING PTV")
                        .font(TTFont.statusLabel())
                        .foregroundStyle(TTColor.accent)
                        .tracking(1.5)
                    ProgressDotsView()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Opening PTV")

                Spacer()
            }
            .frame(minHeight: 480)
        }
    }
}

#Preview {
    OpeningPTVView(confirmationText: "Great! I'll help you plan that journey.")
}
