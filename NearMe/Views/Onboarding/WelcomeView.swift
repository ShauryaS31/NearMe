// Adapted from a prior prototype, used with permission.

import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var logoSize = 44.0

    var body: some View {
        ScreenScaffold {
            VStack(spacing: TTSpacing.xl) {
                Spacer(minLength: TTSpacing.xxl)

                VStack(alignment: .leading, spacing: TTSpacing.sm) {
                    Text("Hello,")
                        .font(TTFont.display())
                        .foregroundStyle(TTColor.ink)

                    Text("Welcome to")
                        .font(TTFont.title())
                        .foregroundStyle(TTColor.ink)

                    let wordmarkLayout = dynamicTypeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: TTSpacing.sm))
                        : AnyLayout(HStackLayout(spacing: TTSpacing.xs))
                    wordmarkLayout {
                        Text("Near")
                            .font(TTFont.display())
                            .foregroundStyle(TTColor.ink)

                        ZStack {
                            Circle()
                                .fill(TTColor.ink)
                                .frame(width: logoSize, height: logoSize)
                            Image(systemName: "waveform")
                                .font(.headline)
                                .foregroundStyle(TTColor.buttonLabel)
                        }
                        .accessibilityHidden(true)

                        Text("Me")
                            .font(TTFont.display())
                            .foregroundStyle(TTColor.logoAccent)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Hello, Welcome to NearMe")

                Spacer()

                PrimaryButton(title: "continue") {
                    coordinator.advanceFromWelcome()
                }
            }
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview("Default") {
    WelcomeView().environmentObject(AppCoordinator())
}

#Preview("Accessibility XXXL") {
    WelcomeView().environmentObject(AppCoordinator())
        .dynamicTypeSize(.accessibility5)
}
