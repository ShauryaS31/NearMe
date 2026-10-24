// Adapted from a prior prototype, used with permission.

import SwiftUI

struct ScreenPermissionView: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        ZStack {
            TTColor.background.ignoresSafeArea()

            TTColor.scrim
                .ignoresSafeArea(edges: [.horizontal, .bottom])

            VStack(spacing: TTSpacing.lg) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(TTColor.chip)
                        .frame(width: 64, height: 64)
                    Image(systemName: "tv")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(TTColor.accent)
                }
                .accessibilityHidden(true)

                VStack(spacing: TTSpacing.sm) {
                    Text("Let NearMe see your screen?")
                        .font(TTFont.title())
                        .foregroundStyle(TTColor.ink)
                        .multilineTextAlignment(.center)

                    Text("So it can guide you inside other apps, NearMe needs to watch what's on screen while you're being helped. It only looks while a session is active.")
                        .font(TTFont.body())
                        .foregroundStyle(TTColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: TTSpacing.sm) {
                    PrimaryButton(title: "allow") {
                        coordinator.resolveScreenPermission(granted: true)
                    }
                    Button("don't allow") {
                        coordinator.resolveScreenPermission(granted: false)
                    }
                    .font(TTFont.body())
                    .foregroundStyle(TTColor.textSecondary)
                    .minimumTapTarget()
                }
            }
            .padding(TTSpacing.xl)
            .frame(maxWidth: 360)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: TTRadius.card, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 24, y: 12)
            .padding(TTSpacing.lg)
        }
    }
}

#Preview {
    ScreenPermissionView().environmentObject(AppCoordinator())
}
