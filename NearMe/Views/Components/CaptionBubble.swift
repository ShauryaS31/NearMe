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
                .foregroundStyle(.white)
                .padding(.top, 2)
                .accessibilityHidden(true)

            Text(text)
                .font(TTFont.callout())
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(6)
                }
                .minimumTapTarget(32)
                .accessibilityLabel("Dismiss guidance message")
            }
        }
        .padding(.horizontal, TTSpacing.md)
        .padding(.vertical, TTSpacing.sm + 2)
        .background(TTColor.ink)
        .clipShape(RoundedRectangle(cornerRadius: TTRadius.bubble, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}

#Preview {
    ZStack {
        TTColor.background
        VStack {
            Spacer()
            CaptionBubble(text: "You're in PTV now — tap Journey Planner.", onDismiss: {})
                .padding()
        }
    }
    .ignoresSafeArea()
}
