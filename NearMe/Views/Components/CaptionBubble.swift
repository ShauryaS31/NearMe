// Adapted from a prior prototype, used with permission.

import SwiftUI

struct CaptionBubble: View {
    @ScaledMetric(relativeTo: .title) private var speakerIconSize = 15.0
    @ScaledMetric(relativeTo: .body) private var dismissIconSize = 13.0
    let text: String
    var icon: String = "speaker.wave.1.fill"
    var onDismiss: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: TTSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: speakerIconSize, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.top, 2)
                .accessibilityHidden(true)

            Text(text)
                .font(.title)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: dismissIconSize, weight: .bold))
                        .foregroundStyle(.primary)
                        .padding(6)
                }
                .minimumTapTarget()
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
            CaptionBubble(text: PracticeStep.forYouOpened.caption(origin: "", destination: ""), onDismiss: {})
                .padding()
        }
    }
    .ignoresSafeArea()
}
