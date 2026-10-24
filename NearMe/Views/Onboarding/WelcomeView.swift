// Adapted from a prior prototype, used with permission.

import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        WelcomeContent(userName: coordinator.userName, hour: Calendar.current.component(.hour, from: Date()),
                       onStart: coordinator.advanceFromWelcome)
    }
}

struct WelcomeContent: View {
    let userName: String
    let hour: Int
    let onStart: () -> Void

    var greeting: String? {
        let name = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != AppCoordinator.placeholderName else { return nil }
        let salutation: String
        switch hour {
        case 0..<12: salutation = "Good morning"
        case 12..<17: salutation = "Good afternoon"
        default: salutation = "Good evening"
        }
        return "\(salutation), \(name)"
    }

    var body: some View {
        ScreenScaffold {
            VStack(alignment: .leading, spacing: TTSpacing.sectionGap) {
                Image(systemName: "hand.wave")
                    .font(.largeTitle)
                    .foregroundStyle(TTColor.accent)
                    .accessibilityHidden(true)
                if let greeting {
                    Text(greeting).font(TTFont.title())
                }
                Text("A little help, one step at a time")
                    .font(TTFont.display())
                    .accessibilityAddTraits(.isHeader)
                VStack(alignment: .leading, spacing: TTSpacing.relatedGap) {
                    Text("Tell NearMe what you want to do.")
                    Text("We'll guide you one step at a time. You stay in control.")
                }
                .font(TTFont.body())
                PrimaryButton(title: "Get started", systemImage: "arrow.right", action: onStart)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}
