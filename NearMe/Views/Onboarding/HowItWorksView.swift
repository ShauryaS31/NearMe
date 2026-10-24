// Adapted from a prior prototype, used with permission.

import SwiftUI

struct HowItWorksView: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        HowItWorksContent(onContinue: coordinator.advanceFromHowItWorks)
    }
}

struct HowItWorksContent: View {
    let onContinue: () -> Void

    var body: some View {
        ScreenScaffold {
            VStack(alignment: .leading, spacing: TTSpacing.sectionGap) {
                Text("How NearMe works")
                    .font(TTFont.title())
                    .accessibilityAddTraits(.isHeader)
                explanation
                PrimaryButton(title: "Try it now", systemImage: "arrow.right", action: onContinue)
                PrimaryButton(title: "Skip", systemImage: "arrow.right", emphasis: .secondary,
                              action: onContinue)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var explanation: some View {
        VStack(alignment: .leading, spacing: TTSpacing.sectionGap) {
            Label("Tell NearMe what you want to do", systemImage: "mic.fill")
            Label("Follow one step at a time", systemImage: "list.number")
            Label("You stay in control", systemImage: "hand.raised")
            Text(ScreenSharingCopy.explanation)
            Text("You can also practise a train trip safely inside NearMe.")
        }
        .font(TTFont.body())
    }
}
