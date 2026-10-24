// Adapted from a prior prototype, used with permission.

import SwiftUI

struct VideoPracticeView: View {
    @ObservedObject var viewModel: VideoPracticeViewModel
    @ObservedObject var engine: TaskPlannerEngine

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                practiceContent
                SessionDock(engine: engine, instruction: viewModel.currentCaption,
                            targetLabel: nil, availableHeight: geometry.size.height)
            }
        }
        .background(Color(.systemBackground))
    }

    private var practiceContent: some View {
        ScrollViewReader { scroll in
            ScrollView {
                VStack(spacing: 24) {
                    VideoPracticeHeader()
                    practiceScreen
                }
                .padding(20)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .task(id: viewModel.step) {
                await Task.yield()
                scroll.scrollTo(viewModel.step.targetLabel, anchor: .center)
            }
        }
        .overlayPreferenceValue(PracticeTargetPreference.self) { targets in
            if !viewModel.isComplete {
                PracticeHighlightLayer(targets: targets, label: viewModel.step.targetLabel,
                                       repeatRevision: viewModel.highlightRepeatRevision)
                    .id(viewModel.step)
            }
        }
        .clipped()
    }

    @ViewBuilder private var practiceScreen: some View {
        switch viewModel.step.screen {
        case .home: VideoPracticeHomeView(onSearch: viewModel.openSearch)
        case .search: VideoPracticeSearchView(viewModel: viewModel)
        case .results: VideoPracticeResultsView(onFirstResult: viewModel.selectFirstResult)
        case .video: VideoPracticePlayerView(viewModel: viewModel)
        }
    }
}

private struct VideoPracticeHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Video app").font(.title.bold())
            Label("Practice", systemImage: "hand.tap").font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(.primary)
    }
}
