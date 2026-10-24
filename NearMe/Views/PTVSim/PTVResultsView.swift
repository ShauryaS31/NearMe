// Adapted from a prior prototype, used with permission.

import SwiftUI

struct PTVResultsView: View {
    let origin: String
    let destination: String

    var body: some View {
        VStack(spacing: 0) {
            PTVTopBar(title: "Journey planner")

            VStack(alignment: .leading, spacing: TTSpacing.xs) {
                Text("\(origin) \u{2192} \(destination)")
                    .font(TTFont.headline())
                    .foregroundStyle(PTVBrand.textPrimary)
                    .padding(.horizontal, TTSpacing.lg)
                    .padding(.top, TTSpacing.md)

                ScrollView {
                    VStack(spacing: TTSpacing.sm) {
                        ForEach(1...3, id: \.self) { number in
                            HStack(alignment: .top, spacing: TTSpacing.md) {
                                Image(systemName: "tram.fill")
                                    .foregroundStyle(PTVBrand.accent)
                                    .padding(.top, 2)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Trip option \(number) (example)")
                                        .font(TTFont.headline())
                                        .foregroundStyle(PTVBrand.textPrimary)
                                    Text("Times show here in the real app")
                                        .font(.body)
                                        .foregroundStyle(PTVBrand.textSecondary)
                                }

                                Spacer()
                            }
                            .padding(TTSpacing.md)
                            .background(PTVBrand.card)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(PTVBrand.hairline, lineWidth: 1)
                            )
                        }
                    }
                    .padding(TTSpacing.lg)
                }
            }
        }
        .background(PTVBrand.background.ignoresSafeArea())
    }
}
