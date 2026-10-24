// Adapted from a prior prototype, used with permission.

import SwiftUI

struct VideoPracticeSearchView: View {
    @ObservedObject var viewModel: VideoPracticeViewModel
    @FocusState private var songFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            songField
            HStack {
                Spacer(minLength: 0)
                Button(action: search) {
                    Label(VideoPracticeScreen.Labels.search, systemImage: "return")
                        .font(.body.weight(.semibold))
                        .minimumTapTarget()
                        .padding(.horizontal, 16)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.step != .submitSearch)
                .practiceTarget(VideoPracticeScreen.Labels.search, active: viewModel.step == .submitSearch)
            }
        }
        .onChange(of: songFocused) { _, focused in
            if focused { viewModel.enterSong() }
        }
        .onChange(of: viewModel.song) { _, _ in viewModel.enterSong() }
    }

    private var songField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(VideoPracticeScreen.Labels.song).font(.headline)
            TextField(VideoPracticeScreen.Labels.song, text: $viewModel.song)
                .font(.body)
                .textFieldStyle(.roundedBorder)
                .minimumTapTarget()
                .focused($songFocused)
                .submitLabel(.search)
                .onSubmit(search)
                .accessibilityLabel(VideoPracticeScreen.Labels.song)
        }
        .practiceTarget(VideoPracticeScreen.Labels.song, active: viewModel.step == .typeSong)
    }

    private func search() {
        songFocused = false
        viewModel.search()
    }
}
