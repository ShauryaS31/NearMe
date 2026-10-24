import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct AskWidgetEntry: TimelineEntry { let date: Date; let state: AskWidgetState }

struct AskWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> AskWidgetEntry {
        AskWidgetEntry(date: Date(), state: AskWidgetState(phase: .ready))
    }
    func getSnapshot(in context: Context, completion: @escaping (AskWidgetEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : AskWidgetEntry(date: Date(), state: AskWidgetStore.read()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<AskWidgetEntry>) -> Void) {
        let now = Date()
        let state = AskWidgetStore.read(at: now)
        var entries = [AskWidgetEntry(date: now, state: state)]
        if let expiry = state.expiresAt, expiry > now {
            entries.append(AskWidgetEntry(date: expiry, state: state.current(at: expiry)))
        }
        completion(Timeline(entries: entries, policy: .never))
    }
}

struct AskNearMeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AskWidgetStore.kind, provider: AskWidgetProvider()) { entry in
            AskWidgetView(state: entry.state)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Ask NearMe")
        .description("Speak to NearMe from your Home Screen after setup.")
        .supportedFamilies([.systemSmall])
    }
}

private struct AskWidgetView: View {
    let state: AskWidgetState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.widgetRenderingMode) private var renderingMode
    private let plum = Color(red: 0.14, green: 0.06, blue: 0.27)
    private let lavender = Color(red: 0.80, green: 0.66, blue: 0.96)

    var body: some View {
        VStack(spacing: 6) {
            if state.phase == .setup {
                if let url = URL(string: "nearme://ask") {
                    Link(destination: url) { orbLabel(title: "Set up NearMe") }
                        .accessibilityHint("Opens NearMe to explain and set up microphone access")
                }
            } else if let id = state.sessionID {
                Label(state.phase.title, systemImage: state.phase == .listening ? "mic.fill" : "hourglass")
                    .font(.headline)
                    .contentTransition(.identity)
                HStack(spacing: 12) {
                    if state.continueInApp, let url = URL(string: "nearme://ask/continue") {
                        Link("Open NearMe", destination: url).frame(maxWidth: .infinity, minHeight: 44)
                    } else if state.phase == .listening {
                        Button(intent: FinishAskNearMeIntent(sessionID: id)) {
                            Text("Finish").frame(maxWidth: .infinity, minHeight: 44)
                        }.buttonStyle(.plain)
                    }
                    Button(intent: StopAskNearMeIntent(sessionID: id)) {
                        Text("Stop").frame(maxWidth: .infinity, minHeight: 44)
                    }.buttonStyle(.plain)
                }.font(.body.weight(.semibold))
            } else {
                Button(intent: StartAskNearMeIntent()) { orbLabel(title: "Ask NearMe") }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Ask NearMe")
                    .accessibilityHint("Starts listening here. Wait for Listening before speaking.")
                if state.phase == .needsApp, let url = URL(string: "nearme://ask/continue") {
                    Link("Continue in NearMe", destination: url).font(.body)
                } else if state.phase == .failed {
                    if let url = URL(string: "nearme://ask") {
                        Link("Couldn’t listen. Help", destination: url).font(.caption)
                    }
                } else if state.phase == .stopped { Text("Stopped").font(.caption) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: state.startedAt)
    }

    private func orbLabel(title: String) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().fill(renderingMode == .fullColor ? lavender.opacity(0.35) : Color.secondary.opacity(0.2))
                Circle().fill(renderingMode == .fullColor ? plum : Color.accentColor).padding(5)
                Image(systemName: "waveform").font(.largeTitle.weight(.medium))
                    .foregroundStyle(renderingMode == .fullColor ? lavender : Color.white)
            }
            .frame(maxWidth: 86, maxHeight: 86).accessibilityHidden(true)
            Text(title).font(.headline).multilineTextAlignment(.center)
                .foregroundStyle(.primary)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct AskRecordingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AskActivityAttributes.self) { context in
            VStack(spacing: 8) {
                AskRecordingStatus(context: context)
                AskRecordingActions(context: context)
            }.padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) { AskRecordingStatus(context: context) }
                DynamicIslandExpandedRegion(.bottom) { AskRecordingActions(context: context) }
            } compactLeading: {
                Image(systemName: context.state.phase == .listening && !context.isStale ? "mic.fill" : "hourglass")
                    .accessibilityLabel(context.isStale ? "Status unavailable" : context.state.phase.title)
            } compactTrailing: {
                if !context.isStale, context.state.phase == .listening, let start = context.state.startedAt {
                    Text(timerInterval: start...context.state.expiresAt, countsDown: false)
                        .monospacedDigit().frame(width: 45)
                } else { Text("NearMe").font(.caption) }
            } minimal: {
                Image(systemName: context.isStale ? "questionmark" : "mic.fill")
                    .accessibilityLabel(context.isStale ? "Status unavailable" : context.state.phase.title)
            }
        }
    }
}

private struct AskRecordingStatus: View {
    let context: ActivityViewContext<AskActivityAttributes>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(spacing: 4) {
            Label(context.isStale ? "Status unavailable" : context.state.phase.title,
                  systemImage: context.state.phase == .listening && !context.isStale ? "mic.fill" : "hourglass")
                .font(.headline)
            if !context.isStale, context.state.phase == .listening, let start = context.state.startedAt {
                Text(timerInterval: start...context.state.expiresAt, countsDown: false).monospacedDigit()
                Text("Speak naturally. Say Stop to finish.").font(.body)
            }
        }.animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: context.state.startedAt)
    }
}

private struct AskRecordingActions: View {
    let context: ActivityViewContext<AskActivityAttributes>
    var body: some View {
        HStack(spacing: 12) {
            if context.state.continueInApp, let url = URL(string: "nearme://ask/continue") {
                Link("Open NearMe", destination: url).frame(minHeight: 44)
            }
            if !context.isStale, context.state.phase == .listening {
                Button(intent: FinishAskNearMeIntent(sessionID: context.attributes.sessionID)) {
                    Label("Finish", systemImage: "checkmark").frame(minHeight: 44)
                }.buttonStyle(.borderedProminent)
            }
            Button(intent: StopAskNearMeIntent(sessionID: context.attributes.sessionID)) {
                Label("Stop", systemImage: "stop.fill").frame(minHeight: 44)
            }.buttonStyle(.bordered)
        }
    }
}
