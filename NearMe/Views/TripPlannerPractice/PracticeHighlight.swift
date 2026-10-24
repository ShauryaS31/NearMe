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
            .modifier(PracticeTargetHint(active: active))
    }
}

private struct PracticeTargetHint: ViewModifier {
    let active: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if active {
            content.accessibilityHint(Text("This is the next step"))
        } else {
            content
        }
    }
}

struct PracticeHighlightLayer: View {
    let targets: [String: PracticeTargetAnchor]
    let label: String

    var body: some View {
        GeometryReader { proxy in
            if let target = targets[label] {
                PracticeHighlight(frame: proxy[target.bounds], cornerRadius: target.cornerRadius)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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

    private var outerFrame: CGRect { frame.insetBy(dx: -lineWidth, dy: -lineWidth) }
    private var outerRadius: CGFloat { cornerRadius + lineWidth }

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                path.addRect(CGRect(origin: .zero, size: geometry.size))
                path.addRoundedRect(in: outerFrame, cornerSize: CGSize(width: outerRadius, height: outerRadius))
            }
            .fill(.black.opacity(0.25), style: FillStyle(eoFill: true))

            if reduceMotion {
                ring
            } else {
                ring.modifier(PracticeRingPulse())
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var ring: some View {
        RoundedRectangle(cornerRadius: outerRadius)
            .strokeBorder(Color.accentColor, lineWidth: lineWidth)
            .frame(width: outerFrame.width, height: outerFrame.height)
            .position(x: frame.midX, y: frame.midY)
    }
}

private struct PracticeRingPulse: ViewModifier {
    @State private var dimmed = false

    func body(content: Content) -> some View {
        content
            .opacity(dimmed ? 0.76 : 1)
            // Two 0.6-second legs make one 1.2-second pulse; only the ring animates.
            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: dimmed)
            .onAppear { dimmed = true }
    }
}
