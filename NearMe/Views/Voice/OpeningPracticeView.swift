// Adapted from a prior prototype, used with permission.

import SwiftUI

struct OpeningPracticeView: View {
    let confirmationText: String

    var body: some View {
        ScrollView {
            VStack(spacing: TTSpacing.xl) {
                Spacer(minLength: TTSpacing.xxl)

                Text(confirmationText)
                    .font(TTFont.title())
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: TTSpacing.md) {
                    Text("Opening Trip planner")
                        .font(TTFont.statusLabel())
                        .foregroundStyle(Color.accentColor)
                        .tracking(1.5)
                    Label("Practice", systemImage: "hand.tap")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    ProgressDotsView(color: .accentColor)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Opening Trip planner. Practice.")

                Spacer()
            }
            .frame(minHeight: 480)
            .padding(TTSpacing.lg)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color(.systemBackground).ignoresSafeArea())
    }
}

#Preview {
    OpeningPracticeView(confirmationText: "Great! I'll help you plan that journey.")
}
