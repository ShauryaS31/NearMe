// Adapted from a prior prototype, used with permission.

import SwiftUI

struct VideoPracticeHomeView: View {
    let onSearch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top, spacing: 12) {
                Text("Home").font(.title2)
                Spacer(minLength: 0)
                Button(action: onSearch) {
                    Label(VideoPracticeScreen.Labels.search, systemImage: "magnifyingglass")
                        .minimumTapTarget()
                }
                .practiceTarget(VideoPracticeScreen.Labels.search, active: true)
            }
            Text("Find a song and practise playing an example video.")
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
