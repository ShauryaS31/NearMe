// Adapted from a prior prototype, used with permission.

import SwiftUI

struct VideoPracticePlayerView: View {
    @ObservedObject var viewModel: VideoPracticeViewModel

    var body: some View {
        VStack(spacing: 24) {
            Text(VideoPracticeScreen.Labels.result(1)).font(.title2)
            Button(action: viewModel.play) {
                Label(VideoPracticeScreen.Labels.play, systemImage: "play.circle.fill")
                    .font(.largeTitle)
                    .frame(maxWidth: .infinity, minHeight: 160)
                    .padding(16)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isComplete)
            .practiceTarget(VideoPracticeScreen.Labels.play, active: !viewModel.isComplete, cornerRadius: 16)
            if viewModel.isComplete {
                Label("Practice complete", systemImage: "checkmark.circle").font(.body)
            }
        }
    }
}
