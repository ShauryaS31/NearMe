// Adapted from a prior prototype, used with permission.

import SwiftUI

struct OpeningPracticeView: View {
    let confirmationText: String

    var body: some View {
        ScrollView {
            VStack(spacing: TTSpacing.sectionGap) {
                Text(confirmationText)
                    .font(TTFont.title())
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: TTSpacing.relatedGap) {
                    Text("Opening Trip planner")
                        .font(.body)
                        .foregroundStyle(TTColor.ink)
                    Label("Practice", systemImage: "hand.tap")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    ProgressDotsView()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Opening Trip planner. Practice.")

                Spacer()
            }
            .padding(TTSpacing.screenInset)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(TTColor.background.ignoresSafeArea())
    }
}

#if DEBUG
#Preview {
    OpeningPracticeView(confirmationText: "Great! I'll help you plan that journey.")
}
#endif
