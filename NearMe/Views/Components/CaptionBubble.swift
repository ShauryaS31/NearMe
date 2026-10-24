// Adapted from a prior prototype, used with permission.

import SwiftUI

struct CaptionBubble: View {
    let text: String
    var icon: String = "speaker.wave.1.fill"
    var onDismiss: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: TTSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.top, 2)
                .accessibilityHidden(true)

            Text(text)
                .font(TTFont.callout())
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.primary)
                        .padding(6)
                }
                .minimumTapTarget(32)
                .accessibilityLabel("Dismiss guidance message")
            }
        }
        .padding(.horizontal, TTSpacing.md)
        .padding(.vertical, TTSpacing.sm + 2)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: TTRadius.bubble, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TTRadius.bubble, style: .continuous)
                .strokeBorder(Color(.separator))
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}

#Preview {
    ZStack {
        Color(.systemBackground)
        VStack {
            Spacer()
            CaptionBubble(text: "You're in Trip planner practice. Tap Journey Planner.", onDismiss: {})
                .padding()
        }
    }
    .ignoresSafeArea()
}
