import SwiftUI

struct VideoPracticeOfferView: View {
    @ObservedObject var engine: TaskPlannerEngine

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Label("Guide complete", systemImage: "checkmark.circle").font(.title)
                        Button { engine.respondToVideoPracticeOffer(accept: true) } label: {
                            Label("Yes, practise", systemImage: "hand.tap").minimumTapTarget()
                        }
                        Button { engine.respondToVideoPracticeOffer(accept: false) } label: {
                            Label("No, return Home", systemImage: "house").minimumTapTarget()
                        }
                    }
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                }
                SessionDock(engine: engine, instruction: TaskPlannerEngine.videoPracticeOffer,
                            targetLabel: nil, availableHeight: geometry.size.height)
            }
        }
        .background(Color(.systemBackground))
    }
}
