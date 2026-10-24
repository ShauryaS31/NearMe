// Adapted from a prior prototype, used with permission.

import SwiftUI

enum TTColor {
    static let background = Color.bg
    static let ink = Color.main
    static let accent = Color.accentPurple
    static let buttonLabel = Color.purpleMed
    static let logoAccent = Color.purpleDark
    static let textSecondary = Color.bodyText
    static let chip = Color.purpleLight
    static let scrim = Color(red: 0x7A / 255, green: 0x6D / 255, blue: 0x87 / 255)
    static let hairline = Color.main.opacity(0.12)
}

/// Semantic text styles built on Dynamic Type so every screen scales with the
/// user's preferred text size (Settings > Accessibility > Display & Text Size)
/// without any manual point sizing.
enum TTFont {
    static func display() -> Font { .system(.largeTitle, design: .rounded).weight(.bold) }
    static func title() -> Font { .system(.title2, design: .rounded).weight(.semibold) }
    static func headline() -> Font { .system(.headline, design: .default).weight(.semibold) }
    static func body() -> Font { .system(.body, design: .default) }
    static func callout() -> Font { .system(.callout, design: .default) }
    static func caption() -> Font { .system(.footnote, design: .default).weight(.medium) }
    /// Used for short all-caps status labels like "NearMe" / "LISTENING....".
    static func statusLabel() -> Font { .system(.caption, design: .rounded).weight(.bold) }
}

enum TTSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

enum TTRadius {
    static let card: CGFloat = 20
    static let control: CGFloat = 28
    static let bubble: CGFloat = 18
}

// 44x44pt minimum tappable area
struct MinimumTapTarget: ViewModifier {
    var size: CGFloat = 44
    func body(content: Content) -> some View {
        content.frame(minWidth: size, minHeight: size)
    }
}

extension View {
    func minimumTapTarget(_ size: CGFloat = 44) -> some View {
        modifier(MinimumTapTarget(size: size))
    }
}
