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
                            Label("Back", systemImage: "chevron.left")
                                .font(TTFont.headline())
                                .foregroundStyle(TTColor.ink)
                                .padding(TTSpacing.relatedGap)
                        }
                        .minimumTapTarget()
                        .accessibilityLabel("Back")
                        Spacer()
                    }
                    .padding(.horizontal, TTSpacing.screenInset)
                }

                ScrollView {
                    content()
                        .padding(.horizontal, TTSpacing.screenInset)
                        .padding(.vertical, TTSpacing.sectionGap)
                        .frame(maxWidth: 560) // keeps content readable on iPad-sized/large iPhones
                        .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .tint(TTColor.accent)
    }
}
