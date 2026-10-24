import SwiftUI
import XCTest
@testable import NearMe

@MainActor
final class UIPolishTests: XCTestCase {
    func testThemeExposesAgreedDimensionsAndSemanticStyles() {
        XCTAssertEqual(TTSpacing.screenInset, 20)
        XCTAssertEqual(TTSpacing.sectionGap, 24)
        XCTAssertEqual(TTSpacing.relatedGap, 12)
        XCTAssertEqual(TTSpacing.cardPadding, 20)
        XCTAssertEqual(TTRadius.card, 20)
        XCTAssertEqual(TTControl.minimumHeight, 56)
        XCTAssertEqual(TTControl.talkHeight, 80)
        XCTAssertEqual(TTColor.background, Color(uiColor: .systemBackground))
        XCTAssertEqual(TTColor.groupedBackground, Color(uiColor: .systemGroupedBackground))
        XCTAssertEqual(TTColor.readingSurface, Color(uiColor: .secondarySystemGroupedBackground))
        XCTAssertEqual(TTColor.accent, Color(uiColor: .systemBlue))
        XCTAssertEqual(TTColor.ink, Color.primary)
        XCTAssertEqual(TTColor.textSecondary, Color.secondary)
        XCTAssertEqual(TTFont.title(), Font.title2.weight(.semibold))
        XCTAssertEqual(TTFont.headline(), Font.headline)
    }

    func testPrimaryButtonGroupsStackAtEveryAccessibilitySize() {
        let standard: [DynamicTypeSize] = [.xSmall, .small, .medium, .large, .xLarge, .xxLarge, .xxxLarge]
        let accessibility: [DynamicTypeSize] = [.accessibility1, .accessibility2, .accessibility3,
                                               .accessibility4, .accessibility5]
        for size in standard {
            XCTAssertFalse(PrimaryButtonLayout.stacksVertically(at: size), "\(size)")
        }
        for size in accessibility {
            XCTAssertTrue(PrimaryButtonLayout.stacksVertically(at: size), "\(size)")
        }
    }

    func testStateRowPrioritisesCapturePreparationAndPlaybackOverPaused() {
        XCTAssertEqual(activity(.idle, speaking: false, preparing: false, starting: false, paused: false), .ready)
        XCTAssertEqual(activity(.idle, speaking: false, preparing: false, starting: false, paused: true), .paused)
        XCTAssertEqual(activity(.listening, speaking: false, preparing: false, starting: false, paused: true), .listening)
        XCTAssertEqual(activity(.finishing, speaking: false, preparing: false, starting: false, paused: false), .preparing)
        XCTAssertEqual(activity(.thinking, speaking: false, preparing: false, starting: false, paused: false), .preparing)
        XCTAssertEqual(activity(.idle, speaking: false, preparing: false, starting: true, paused: false), .preparing)
        XCTAssertEqual(activity(.speaking("Hello"), speaking: true, preparing: true, starting: false, paused: false), .preparing)
        XCTAssertEqual(activity(.speaking("Hello"), speaking: true, preparing: false, starting: false, paused: true), .speaking)
        XCTAssertEqual(VoiceOrbState.idle.accessibilityLabel, "Start listening")
        XCTAssertEqual(VoiceOrbState.speaking.accessibilityLabel, "Start listening")
        XCTAssertEqual(VoiceOrbState.listening.accessibilityLabel, "Stop listening")
    }

    func testCurrentExchangeKeepsEveryOtherTurnInEarlierConversation() {
        let turns: [ConversationTurn] = [
            ConversationTurn(speaker: .user, text: "Train trip"),
            ConversationTurn(speaker: .nearme, text: "Where to?"),
            ConversationTurn(speaker: .user, text: "Town Hall"),
            ConversationTurn(speaker: .nearme, text: "Got it."),
            ConversationTurn(speaker: .nearme, text: "Where from?")
        ]
        let presentation = ConversationPresentation(turns: turns, liveTranscript: "")
        XCTAssertEqual(presentation.userText, "Town Hall")
        XCTAssertEqual(presentation.replyText, "Where from?")
        XCTAssertEqual(presentation.earlier, [turns[0], turns[1], turns[3]])
    }

    func testNewListeningTurnDoesNotPairNewWordsWithAnOldReply() {
        let turns = [
            ConversationTurn(speaker: .user, text: "Town Hall"),
            ConversationTurn(speaker: .nearme, text: "Where from?")
        ]
        let presentation = ConversationPresentation(turns: turns, liveTranscript: "Central")
        XCTAssertEqual(presentation.userText, "Central")
        XCTAssertNil(presentation.replyText)
        XCTAssertEqual(presentation.earlier, turns)
    }

    func testFinalTranscriptIsNotDuplicatedWhilePreparing() {
        let turns = [
            ConversationTurn(speaker: .nearme, text: "Where from?"),
            ConversationTurn(speaker: .user, text: "Central")
        ]
        let presentation = ConversationPresentation(turns: turns, liveTranscript: "Central")
        XCTAssertEqual(presentation.userText, "Central")
        XCTAssertNil(presentation.replyText)
        XCTAssertEqual(presentation.earlier, [turns[0]])
        let empty = ConversationPresentation(turns: [], liveTranscript: "")
        XCTAssertNil(empty.userText)
        XCTAssertNil(empty.replyText)
        XCTAssertTrue(empty.earlier.isEmpty)
    }

    func testCoachProgressCountsCompletedStepsNotCurrentStep() {
        let session = CoachSession(guide: nil, request: "Send a photo", person: nil,
                                   generalSteps: ["One", "Two", "Three", "Four", "Five", "Six"],
                                   stepIndex: 2, text: "Three")
        let presentation = CoachStepPresentation(session: session)
        XCTAssertEqual(presentation.title, "Send a photo")
        XCTAssertEqual(presentation.countText, "Step 3 of 6")
        XCTAssertTrue(presentation.hasKnownTotal)
        XCTAssertEqual(presentation.completedSteps, 2)
        XCTAssertEqual(presentation.totalSteps, 6)
    }

    func testWelcomeMergeRetainsExplainerAndSessionSteps() {
        let coordinator = AppCoordinator()
        XCTAssertEqual(coordinator.route, .welcome)
        coordinator.advanceFromWelcome()
        XCTAssertEqual(coordinator.route, .howItWorks)
        coordinator.advanceFromHowItWorks()
        XCTAssertEqual(coordinator.route, .session)
        coordinator.restartOnboarding()
        XCTAssertEqual(coordinator.route, .welcome)
    }

    func testWelcomeGreetsKnownNamesOnlyAndKeepsTimeOfDay() {
        XCTAssertNil(WelcomeContent(userName: "", hour: 9, onStart: {}).greeting)
        XCTAssertNil(WelcomeContent(userName: "Friend", hour: 9, onStart: {}).greeting)
        XCTAssertEqual(WelcomeContent(userName: "Shaurya", hour: 9, onStart: {}).greeting, "Good morning, Shaurya")
        XCTAssertEqual(WelcomeContent(userName: "Shaurya", hour: 14, onStart: {}).greeting, "Good afternoon, Shaurya")
        XCTAssertEqual(WelcomeContent(userName: "Shaurya", hour: 20, onStart: {}).greeting, "Good evening, Shaurya")
    }

    private func activity(_ state: TaskPlannerState, speaking: Bool, preparing: Bool,
                          starting: Bool, paused: Bool) -> VoiceActivity {
        VoiceActivity.resolve(plannerState: state, isSpeaking: speaking, isPreparing: preparing,
                              isStartingListening: starting, isPaused: paused)
    }
}
