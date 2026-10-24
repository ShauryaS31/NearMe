// Adapted from a prior prototype, used with permission.

import SwiftUI

enum TTColor {
    static let background = Color(uiColor: .systemBackground)
    static let groupedBackground = Color(uiColor: .systemGroupedBackground)
    static let readingSurface = Color(uiColor: .secondarySystemGroupedBackground)
    static let ink = Color.primary
    static let accent = Color(uiColor: .systemBlue)
    static let textSecondary = Color.secondary
}

/// Semantic text styles built on Dynamic Type so every screen scales with the
/// user's preferred text size (Settings > Accessibility > Display & Text Size)
/// without any manual point sizing.
enum TTFont {
    static func display() -> Font { .largeTitle }
    static func title() -> Font { .title2.weight(.semibold) }
    static func headline() -> Font { .headline }
    static func body() -> Font { .system(.body, design: .default) }
    // These legacy styles belong to the imitated practice app, which keeps its look.
    static func callout() -> Font { .system(.callout, design: .default) }
    static func caption() -> Font { .system(.footnote, design: .default).weight(.medium) }
}

enum TTSpacing {
    static let screenInset: CGFloat = 20
    static let sectionGap: CGFloat = 24
    static let relatedGap: CGFloat = 12
    static let cardPadding: CGFloat = 20
    // Preserve legacy spacing for the practice app's own content.
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
    static let bubble: CGFloat = 20
}

enum TTControl {
    static let minimumHeight: CGFloat = 56
    static let talkHeight: CGFloat = 80
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
