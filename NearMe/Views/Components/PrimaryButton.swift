// Adapted from a prior prototype, used with permission.

import SwiftUI

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(TTFont.headline())
                .lineLimit(2)
                .minimumScaleFactor(0.9)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, TTSpacing.md)
                .padding(.horizontal, TTSpacing.lg)
        }
        .background(TTColor.ink)
        .foregroundStyle(TTColor.buttonLabel)
        .clipShape(RoundedRectangle(cornerRadius: TTRadius.control, style: .continuous))
        .opacity(isEnabled ? 1 : 0.5)
        .minimumTapTarget(48)
    }
}

#Preview {
    VStack(spacing: 16) {
        PrimaryButton(title: "continue", action: {})
        PrimaryButton(title: "cancel", action: {})
        PrimaryButton(title: "end session", action: {})
    }
    .padding()
    .background(TTColor.background)
}
