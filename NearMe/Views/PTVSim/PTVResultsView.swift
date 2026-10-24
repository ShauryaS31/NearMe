// Adapted from a prior prototype, used with permission.

import SwiftUI

struct PTVResultsView: View {
    let origin: String
    let destination: String

    private struct Option: Identifiable {
        let id = UUID()
        let departure: String
        let arrival: String
        let travelTime: String
        let platform: String
    }

    private let options: [Option] = [
        Option(departure: "9:33 pm", arrival: "10:33 pm", travelTime: "Travel time: 1 hr", platform: "Platform 2"),
        Option(departure: "9:54 pm", arrival: "10:35 pm", travelTime: "Travel time: 41 mins", platform: "Platform 1"),
        Option(departure: "10:04 pm", arrival: "10:36 pm", travelTime: "Travel time: 32 mins", platform: "Platform 1"),
    ]

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
                        ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                            HStack(alignment: .top, spacing: TTSpacing.md) {
                                Image(systemName: "tram.fill")
                                    .foregroundStyle(PTVBrand.accent)
                                    .padding(.top, 2)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(option.departure) – \(option.arrival)")
                                        .font(TTFont.headline())
                                        .foregroundStyle(PTVBrand.textPrimary)
                                    Text("\(option.travelTime) · \(option.platform)")
                                        .font(TTFont.caption())
                                        .foregroundStyle(PTVBrand.textSecondary)
                                }

                                Spacer()

                                if index == 0 {
                                    Text("Next")
                                        .font(.system(.caption2, design: .default).weight(.bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(PTVBrand.accent)
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(TTSpacing.md)
                            .background(PTVBrand.card)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(index == 0 ? PTVBrand.accent : PTVBrand.hairline, lineWidth: index == 0 ? 2 : 1)
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
