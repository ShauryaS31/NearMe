// Adapted from a prior prototype, used with permission.

import SwiftUI
import Combine

struct ProgressDotsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var activeIndex = 0

    private let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(TTColor.accent.opacity(dotOpacity(for: index)))
                    .frame(width: 10, height: 10)
            }
        }
        .onReceive(timer) { _ in
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                activeIndex = (activeIndex + 1) % 3
            }
        }
        .accessibilityHidden(true)
    }

    private func dotOpacity(for index: Int) -> Double {
        if reduceMotion { return 0.6 }
        return activeIndex == index ? 1.0 : 0.3
    }
}

#Preview {
    ProgressDotsView()
        .padding()
        .background(TTColor.background)
}
