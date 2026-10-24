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
        XCTAssertEqual(AppCoordinator().userName, AppCoordinator.placeholderName)
        XCTAssertNil(WelcomeContent(userName: AppCoordinator.placeholderName, hour: 9, onStart: {}).greeting)
        XCTAssertEqual(WelcomeContent(userName: "Shaurya", hour: 9, onStart: {}).greeting, "Good morning, Shaurya")
        XCTAssertEqual(WelcomeContent(userName: "Shaurya", hour: 14, onStart: {}).greeting, "Good afternoon, Shaurya")
        XCTAssertEqual(WelcomeContent(userName: "Shaurya", hour: 20, onStart: {}).greeting, "Good evening, Shaurya")
    }

    func testFallbackSessionUsesHomeReplyInsteadOfCoachCard() {
        let session = generalSession(steps: [CoachText.generalFallback], text: CoachText.generalFallback)
        XCTAssertEqual(CoachPresentation.kind(for: session), .homeReply)
        XCTAssertFalse(CoachPresentation.showsCoachCard(session: session, error: nil))
        XCTAssertEqual(CoachPresentation.reply(session: session, error: nil), CoachText.generalFallback)
        XCTAssertEqual(CoachPresentation.kind(for: nil), .homeReply)
        let empty = generalSession(steps: [], text: "")
        XCTAssertEqual(CoachPresentation.kind(for: empty), .homeReply)
        XCTAssertEqual(CoachPresentation.reply(session: empty, error: nil), CoachText.generalFallback)
    }

    func testRealGeneralStepsIncludingSingleStepUseCoachCard() {
        for steps in [["Open the app."], ["Open the app.", "Choose a photo."]] {
            let session = generalSession(steps: steps, text: "Open the app.")
            XCTAssertEqual(CoachPresentation.kind(for: session), .coachCard)
            XCTAssertTrue(CoachPresentation.showsCoachCard(session: session, error: nil))
            XCTAssertNil(CoachPresentation.reply(session: session, error: nil))
            XCTAssertNil(CoachPresentation.appLaunch(for: session))
        }
    }

    func testFallbackRewriteOfGeneralStepsUsesHomeReply() {
        let session = generalSession(steps: ["Open the app."], text: CoachText.generalFallback)
        XCTAssertEqual(CoachPresentation.kind(for: session), .homeReply)
    }

    func testErrorsAndNoWordsUseHomeReplyEvenWithExistingCoach() {
        let session = generalSession(steps: ["Open the app."], text: "Open the app.")
        let noWords = VoiceDiagnostics.message(for: VoiceInputError.noSpeechDetected)
        for message in ["Something went wrong.", noWords] {
            XCTAssertFalse(CoachPresentation.showsCoachCard(session: session, error: message))
            XCTAssertEqual(CoachPresentation.reply(session: session, error: message), message)
            XCTAssertEqual(CoachPresentation.reply(session: nil, error: message), message)
        }
    }

    func testGuideUsesCoachCardAndWhatsAppOpenLinkWithoutChangingStep() throws {
        let guides: [HelpGuide] = try GuideLibrary.load()
        let guide = try XCTUnwrap(guides.first { $0.id == "whatsapp_send_photo" })
        let session = CoachSession(guide: guide, request: "Send a photo", person: nil,
                                   generalSteps: [], stepIndex: 1, text: guide.steps[1].instruction)
        XCTAssertEqual(CoachPresentation.kind(for: session), .coachCard)
        let launch = try XCTUnwrap(CoachPresentation.appLaunch(for: session))
        XCTAssertEqual(launch.app, "WhatsApp")
        XCTAssertEqual(launch.url.absoluteString, "whatsapp://")
        XCTAssertEqual(session.stepIndex, 1)
        XCTAssertEqual(session.text, guide.steps[1].instruction)
    }

    func testGuideWithoutSchemeHidesOpenApp() throws {
        let guides: [HelpGuide] = try GuideLibrary.load()
        let guide = try XCTUnwrap(guides.first { $0.appURLScheme == nil })
        let session = CoachSession(guide: guide, request: guide.title, person: nil,
                                   generalSteps: [], stepIndex: 0, text: guide.steps[0].instruction)
        XCTAssertEqual(CoachPresentation.kind(for: session), .coachCard)
        XCTAssertNil(CoachPresentation.appLaunch(for: session))
    }

    func testHomeReplyKeepsUserWordsAndDoesNotDuplicateLastReply() {
        let turns: [ConversationTurn] = [
            ConversationTurn(speaker: .user, text: "Can you help?"),
            ConversationTurn(speaker: .nearme, text: CoachText.generalFallback)
        ]
        let presentation = ConversationPresentation(turns: turns, liveTranscript: "")
            .withReply(CoachText.generalFallback)
        XCTAssertEqual(presentation.userText, "Can you help?")
        XCTAssertEqual(presentation.replyText, CoachText.generalFallback)
        XCTAssertTrue(presentation.earlier.isEmpty)
    }

    func testTalkVoiceControlNamesIncludeVisibleTitleAndOriginalAction() {
        XCTAssertEqual(VoiceOrbState.idle.inputLabels, ["Talk to NearMe", "Start listening"])
        XCTAssertEqual(VoiceOrbState.listening.inputLabels,
                       ["Listening... tap when you're done", "Stop listening"])
    }

    func testErrorReplyRetainsPreviousPromptInEarlierConversation() {
        let prompt = ConversationTurn(speaker: .nearme, text: "Where would you like to go?")
        let presentation = ConversationPresentation(turns: [prompt], liveTranscript: "")
            .withReply("I didn't hear any words.")
        XCTAssertEqual(presentation.replyText, "I didn't hear any words.")
        XCTAssertEqual(presentation.earlier, [prompt])
    }

    private func generalSession(steps: [String], text: String) -> CoachSession {
        CoachSession(guide: nil, request: "Help me", person: nil, generalSteps: steps, stepIndex: 0, text: text)
    }

    private func activity(_ state: TaskPlannerState, speaking: Bool, preparing: Bool,
                          starting: Bool, paused: Bool) -> VoiceActivity {
        VoiceActivity.resolve(plannerState: state, isSpeaking: speaking, isPreparing: preparing,
                              isStartingListening: starting, isPaused: paused)
    }
}
