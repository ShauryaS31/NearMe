// Adapted from a prior prototype, used with permission.

import SwiftUI

struct GoodMorningView: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning,"
        case 12..<17: return "Good afternoon,"
        default: return "Good evening,"
        }
    }

    private var symbolName: String {
        let hour = Calendar.current.component(.hour, from: Date())
        return (6..<18).contains(hour) ? "sun.max.fill" : "moon.stars.fill"
    }

    var body: some View {
        ScreenScaffold {
            VStack {
                Spacer(minLength: TTSpacing.xl)

                VStack(spacing: TTSpacing.sm) {
                    Image(systemName: symbolName)
                        .font(.system(size: 44))
                        .foregroundStyle(TTColor.ink)
                        .accessibilityHidden(true)

                    VStack(spacing: TTSpacing.xs) {
                        Text(greeting)
                            .font(TTFont.title())
                        Text(coordinator.userName)
                            .font(TTFont.display())
                    }
                    .foregroundStyle(TTColor.ink)
                    .multilineTextAlignment(.center)
                }
                .accessibilityElement(children: .combine)
                Spacer()
                VStack {
                    PrimaryButton(title: "start") {
                        coordinator.advanceFromGoodMorning()
                    }
                }
            }
            .frame(minHeight: 480)
        }
    }
}

#Preview {
    GoodMorningView().environmentObject(AppCoordinator())
}
