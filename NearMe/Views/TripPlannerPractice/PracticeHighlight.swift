import SwiftUI

nonisolated struct PracticeTargetAnchor {
    let bounds: Anchor<CGRect>
    let cornerRadius: CGFloat
}

nonisolated struct PracticeTargetPreference: PreferenceKey {
    static var defaultValue: [String: PracticeTargetAnchor] { [:] }
    static func reduce(value: inout [String: PracticeTargetAnchor], nextValue: () -> [String: PracticeTargetAnchor]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}

extension View {
    func practiceTarget(_ label: String, active: Bool, cornerRadius: CGFloat = 12) -> some View {
        self
            .id(label)
            .anchorPreference(key: PracticeTargetPreference.self, value: .bounds) { bounds in
                active ? [label: PracticeTargetAnchor(bounds: bounds, cornerRadius: cornerRadius)] : [:]
            }
            .accessibilityHint(active ? "This is the next step" : "")
    }
}

struct PracticeHighlight: View {
    let frame: CGRect
    let cornerRadius: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    private var lineWidth: CGFloat {
        if contrast == .increased { return 8 }
        return reduceMotion ? 6 : 4
    }

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                path.addRect(CGRect(origin: .zero, size: geometry.size))
                path.addRoundedRect(in: frame, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
            }
            .fill(.black.opacity(0.25), style: FillStyle(eoFill: true))

            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
                let phase = context.date.timeIntervalSinceReferenceDate * 2 * .pi / 1.2
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color.accentColor, lineWidth: lineWidth)
                    .opacity(reduceMotion ? 1 : 0.88 + 0.12 * cos(phase))
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
