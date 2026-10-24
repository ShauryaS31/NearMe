// Adapted from a prior prototype, used with permission.

import SwiftUI

enum ButtonEmphasis { case primary, secondary }

struct PrimaryButton: View {
    let title: String
    let systemImage: String
    var emphasis: ButtonEmphasis = .primary
    let action: () -> Void

    var body: some View {
        Group {
            switch emphasis {
            case .primary: button.buttonStyle(.borderedProminent)
            case .secondary: button.buttonStyle(.bordered)
            }
        }
        .tint(TTColor.accent)
    }

    private var button: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(TTFont.headline())
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: TTControl.minimumHeight)
        }
    }
}

/// Shared by groups of PrimaryButtons and tested without a snapshot library.
enum PrimaryButtonLayout {
    static func stacksVertically(at size: DynamicTypeSize) -> Bool {
        size.isAccessibilitySize
    }
}

struct AdaptiveButtonRow<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ViewBuilder var content: () -> Content

    private var layout: AnyLayout {
        if PrimaryButtonLayout.stacksVertically(at: dynamicTypeSize) {
            return AnyLayout(VStackLayout(spacing: TTSpacing.relatedGap))
        }
        return AnyLayout(HStackLayout(spacing: TTSpacing.relatedGap))
    }

    var body: some View { layout { content() } }
}
