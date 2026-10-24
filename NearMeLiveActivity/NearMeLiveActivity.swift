import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@main
struct NearMeLiveActivityBundle: WidgetBundle {
    var body: some Widget { CoachLiveActivity() }
}

struct CoachLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CoachActivityAttributes.self) { context in
            CoachLockScreen(context: context)
                .widgetURL(CoachDeepLink.url(sessionID: context.attributes.sessionID))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.instruction)
                        .font(.headline)
                        .lineLimit(2)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    CoachActivityActions(context: context, linkTitle: "Open NearMe")
                }
            } compactLeading: {
                Image(systemName: "hand.raised")
                    .accessibilityLabel("NearMe")
            } compactTrailing: {
                CoachActivityProgress(context: context)
            } minimal: {
                CoachActivityProgress(context: context)
            }
            .widgetURL(CoachDeepLink.url(sessionID: context.attributes.sessionID))
        }
    }
}

private struct CoachLockScreen: View {
    let context: ActivityViewContext<CoachActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(context.attributes.guideTitle).font(.headline)
            Text(context.state.instruction)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            if !context.state.isComplete {
                CoachActivityActions(context: context, linkTitle: "Resume")
            }
        }
        .foregroundStyle(.primary)
        .padding()
    }
}

private struct CoachActivityProgress: View {
    let context: ActivityViewContext<CoachActivityAttributes>

    var body: some View {
        Text(context.state.progressText(totalSteps: context.attributes.totalSteps))
            .monospacedDigit()
            .accessibilityLabel("Step \(context.state.stepNumber) of \(context.attributes.totalSteps)")
    }
}

private struct CoachActivityActions: View {
    let context: ActivityViewContext<CoachActivityAttributes>
    let linkTitle: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { actions }
            VStack(alignment: .leading, spacing: 8) { actions }
        }
        .buttonStyle(.bordered)
        .font(.body)
    }

    @ViewBuilder private var actions: some View {
        if !context.state.isComplete {
            Button(intent: CoachDoneIntent(sessionID: context.attributes.sessionID,
                                           expectedRevision: context.state.revision)) {
                Label(context.state.actionTitle, systemImage: "checkmark").frame(minHeight: 44)
            }
            .accessibilityLabel(context.state.canCheckAndListen == true ? "Check screen and listen" : "Mark step done")
            .accessibilityHint(context.state.actionHint)
        }
        if let url = CoachDeepLink.url(sessionID: context.attributes.sessionID) {
            Link(destination: url) {
                Label(linkTitle, systemImage: "hand.raised").frame(minHeight: 44)
            }
            .accessibilityLabel(linkTitle == "Resume" ? "Resume guide in NearMe" : "Open NearMe")
        }
    }
}
