// Adapted from a prior prototype, used with permission.

import SwiftUI

struct CaptionBubble: View {
    let text: String
    var icon: String = "speaker.wave.1.fill"
    var onDismiss: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: TTSpacing.relatedGap) {
            Label(text, systemImage: icon)
                .font(TTFont.body())
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let onDismiss {
                PrimaryButton(title: "Dismiss", systemImage: "xmark", emphasis: .secondary,
                              action: onDismiss)
                    .accessibilityLabel("Dismiss guidance message")
            }
        }
        .foregroundStyle(TTColor.ink)
        .padding(TTSpacing.cardPadding)
        .background(TTColor.readingSurface,
                    in: RoundedRectangle(cornerRadius: TTRadius.card, style: .continuous))
    }
}
