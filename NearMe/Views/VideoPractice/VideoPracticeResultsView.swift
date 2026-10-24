// Adapted from a prior prototype, used with permission.

import SwiftUI

struct VideoPracticeResultsView: View {
    let onFirstResult: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Results").font(.title2)
            ForEach(1...3, id: \.self) { number in
                Button {
                    if number == 1 { onFirstResult() }
                } label: {
                    Label(VideoPracticeScreen.Labels.result(number), systemImage: "video")
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .minimumTapTarget()
                        .padding(16)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(number != 1)
                .practiceTarget(VideoPracticeScreen.Labels.result(number), active: number == 1)
            }
        }
    }
}
