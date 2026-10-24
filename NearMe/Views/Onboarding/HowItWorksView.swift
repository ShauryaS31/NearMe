// Adapted from a prior prototype, used with permission.

import SwiftUI

struct HowItWorksView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @ScaledMetric(relativeTo: .title) private var iconSize = 64.0

    var body: some View {
        ScreenScaffold {
            VStack(spacing: TTSpacing.lg) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(TTColor.chip)
                        .frame(width: iconSize, height: iconSize)
                    Image(systemName: "tv")
                        .font(.title.weight(.medium))
                        .foregroundStyle(TTColor.accent)
                }
                .accessibilityHidden(true)

                VStack(spacing: TTSpacing.sm) {
                    Text("How NearMe works")
                        .font(TTFont.title())
                        .foregroundStyle(TTColor.ink)
                        .multilineTextAlignment(.center)

                    Text("NearMe shows you practice copies of everyday apps, so you can learn safely. It never looks at your other apps.")
                        .font(TTFont.body())
                        .foregroundStyle(TTColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                PrimaryButton(title: "continue") {
                    coordinator.advanceFromHowItWorks()
                }
            }
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview("Default") {
    HowItWorksView().environmentObject(AppCoordinator())
}

#Preview("Accessibility XXXL") {
    HowItWorksView().environmentObject(AppCoordinator())
        .dynamicTypeSize(.accessibility5)
}
