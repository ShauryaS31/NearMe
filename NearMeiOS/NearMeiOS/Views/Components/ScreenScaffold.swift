// Adapted from a prior prototype, used with permission.

import SwiftUI

struct ScreenScaffold<Content: View>: View {
    var showBackButton: Bool = false
    var onBack: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            TTColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                if showBackButton {
                    HStack {
                        Button(action: { onBack?() }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(TTColor.ink)
                                .padding(TTSpacing.xs)
                        }
                        .minimumTapTarget()
                        .accessibilityLabel("Back")
                        Spacer()
                    }
                    .padding(.horizontal, TTSpacing.xs)
                }

                ScrollView {
                    content()
                        .padding(.horizontal, TTSpacing.lg)
                        .padding(.vertical, TTSpacing.lg)
                        .frame(maxWidth: 560) // keeps content readable on iPad-sized/large iPhones
                        .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
    }
}
