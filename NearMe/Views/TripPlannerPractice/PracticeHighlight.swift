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
    let repeatRevision: Int

    var body: some View {
        GeometryReader { proxy in
            if let target = targets[label] {
                PracticeHighlight(frame: proxy[target.bounds], cornerRadius: target.cornerRadius,
                                  targetID: label, repeatRevision: repeatRevision)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct PracticeHighlight: View {
    let frame: CGRect
    let cornerRadius: CGFloat
    let targetID: String
    let repeatRevision: Int
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
            .fill(Color(.separator).opacity(0.5), style: FillStyle(eoFill: true))

            ring.modifier(PracticeRingPulse(request: pulseRequest))
                // Repeat starts from a fresh, fully opaque ring, even mid-cycle.
                .id(repeatRevision)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var pulseRequest: PracticePulseRequest {
        PracticePulseRequest(targetID: targetID, repeatRevision: repeatRevision, reduceMotion: reduceMotion)
    }

    private var ring: some View {
        RoundedRectangle(cornerRadius: outerRadius)
            .strokeBorder(Color.accentColor, lineWidth: lineWidth)
            .frame(width: outerFrame.width, height: outerFrame.height)
            .position(x: frame.midX, y: frame.midY)
    }
}

nonisolated struct PracticePulseRequest: Equatable {
    let targetID: String
    let repeatRevision: Int
    let reduceMotion: Bool
}

/// Pure state: layout updates do not restart pulses; only a new target or Repeat does.
nonisolated struct PracticeHighlightState {
    private var request: PracticePulseRequest?
    private(set) var pulsesRemaining = 0

    mutating func update(_ next: PracticePulseRequest) {
        let shouldRestart = request?.targetID != next.targetID
            || request?.repeatRevision != next.repeatRevision
        request = next
        if next.reduceMotion {
            pulsesRemaining = 0
        } else if shouldRestart {
            pulsesRemaining = 3
        }
    }

    mutating func completeCycle() {
        pulsesRemaining = max(0, pulsesRemaining - 1)
    }
}

private struct PracticeRingPulse: ViewModifier {
    let request: PracticePulseRequest
    @State private var highlightState = PracticeHighlightState()
    @State private var dimmed = false

    func body(content: Content) -> some View {
        content
            .opacity(request.reduceMotion ? 1 : (dimmed ? 0.76 : 1))
            .task(id: request) { await pulse(for: request) }
    }

    @MainActor
    private func pulse(for request: PracticePulseRequest) async {
        guard !Task.isCancelled else { return }
        highlightState.update(request)
        var reset = Transaction(animation: nil)
        reset.disablesAnimations = true
        withTransaction(reset) { dimmed = false }

        do {
            guard highlightState.pulsesRemaining > 0 else { return }
            // Let the opaque starting frame appear before the first animated leg.
            try await Task.sleep(for: .milliseconds(50))
            try Task.checkCancellation()
            while highlightState.pulsesRemaining > 0 {
                // Two 0.6-second legs make one cycle; only ring opacity changes.
                withAnimation(.easeInOut(duration: 0.6)) { dimmed = true }
                try await Task.sleep(for: .milliseconds(600))
                try Task.checkCancellation()
                withAnimation(.easeInOut(duration: 0.6)) { dimmed = false }
                try await Task.sleep(for: .milliseconds(600))
                try Task.checkCancellation()
                highlightState.completeCycle()
            }
        } catch {
            // A new target, Repeat, Reduce Motion or removal cancels this run.
            // Do not let an old task mutate the replacement run's state.
        }
    }
}
