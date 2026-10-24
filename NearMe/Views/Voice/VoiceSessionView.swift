// Adapted from a prior prototype, used with permission.

import SwiftUI

struct PlaceSuggestionsView: View {
    @ObservedObject var engine: TaskPlannerEngine

    var body: some View {
        VStack(alignment: .leading, spacing: TTSpacing.relatedGap) {
            Text("I heard: \(engine.suggestionTranscript)").font(TTFont.body())
            Text(engine.suggestionQuestion).font(TTFont.title())
            ForEach(engine.placeSuggestions, id: \.self) { place in
                PrimaryButton(title: place, systemImage: "mappin.circle", emphasis: .secondary) {
                    engine.chooseSuggestedPlace(place)
                }
            }
            PrimaryButton(title: "Keep what I said", systemImage: "checkmark", emphasis: .secondary,
                          action: engine.keepSuggestedPlace)
            PrimaryButton(title: "Say it again", systemImage: "mic.fill", emphasis: .secondary,
                          action: engine.retrySuggestedPlace)
        }
    }

}

/// Read-only grouping; it never changes the engine's conversation or speech state.
struct ConversationPresentation {
    let userText: String?
    private(set) var replyText: String?
    private(set) var earlier: [ConversationTurn]
    private let currentReply: ConversationTurn?

    var hasContent: Bool { userText != nil || replyText != nil || !earlier.isEmpty }

    init(turns: [ConversationTurn], liveTranscript: String) {
        let lastUserIndex: Int? = turns.lastIndex { $0.speaker == .user }
        let startIndex: Int = lastUserIndex ?? max(0, turns.count - 1)
        let current: [ConversationTurn] = Array(turns.dropFirst(startIndex))
        let lastReply: ConversationTurn? = current.last { $0.speaker == .nearme }
        let lastUser: ConversationTurn? = current.last { $0.speaker == .user }
        currentReply = liveTranscript.isEmpty ? lastReply : nil
        if liveTranscript.isEmpty {
            userText = lastUser?.text
            replyText = lastReply?.text
            // Keep every older reply, even when several prompts follow one user turn.
            let currentIDs = Set([lastUser?.id, lastReply?.id].compactMap { $0 })
            earlier = turns.filter { !currentIDs.contains($0.id) }
        } else {
            userText = liveTranscript
            replyText = nil
            // Recognised final text can already have been appended while thinking.
            if lastUser?.text == liveTranscript, let lastUser {
                earlier = turns.filter { $0.id != lastUser.id }
            } else {
                earlier = turns
            }
        }
    }

    func withReply(_ text: String) -> Self {
        var presentation = self
        if let currentReply, currentReply.text != text {
            presentation.earlier.append(currentReply)
        }
        presentation.replyText = text
        return presentation
    }
}

struct ConversationTranscript: View {
    let presentation: ConversationPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: TTSpacing.sectionGap) {
            if let userText = presentation.userText {
                turn(label: "You said", text: userText, isCurrentReply: false)
            }
            if let replyText = presentation.replyText {
                turn(label: "NearMe", text: replyText, isCurrentReply: true)
            }
            if !presentation.earlier.isEmpty {
                DisclosureGroup("Earlier conversation") {
                    VStack(alignment: .leading, spacing: TTSpacing.sectionGap) {
                        ForEach(presentation.earlier) { entry in
                            turn(label: entry.speaker == .user ? "You said" : "NearMe",
                                 text: entry.text, isCurrentReply: false)
                        }
                    }
                    .padding(.top, TTSpacing.relatedGap)
                }
                .font(TTFont.body())
            }
        }
        .padding(TTSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TTColor.readingSurface,
                    in: RoundedRectangle(cornerRadius: TTRadius.card, style: .continuous))
    }

    private func turn(label: String, text: String, isCurrentReply: Bool) -> some View {
        VStack(alignment: .leading, spacing: TTSpacing.relatedGap) {
            Text(label).font(TTFont.body()).foregroundStyle(TTColor.textSecondary)
            Text(text)
                .font(isCurrentReply ? TTFont.title() : TTFont.body())
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
struct SessionDebugMenu: View {
    @ObservedObject var engine: TaskPlannerEngine

    var body: some View {
        Menu {
            Toggle("Show debug info", isOn: $engine.showsDebugInfo)
        } label: {
            Label("More", systemImage: "ellipsis.circle").minimumTapTarget()
        }
    }
}
#endif
