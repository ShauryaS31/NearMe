import SwiftUI
import XCTest
import UIKit
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

    func testWelcomeMergeRetainsExplainerAndSessionSteps() throws {
        let suite = "NearMe.Onboarding.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let coordinator = AppCoordinator(guides: [], defaults: defaults)
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
        XCTAssertEqual(AppCoordinator(guides: []).userName, AppCoordinator.placeholderName)
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

    func testFallbackRewriteOfGeneralStepsKeepsCoachCard() {
        var session = generalSession(steps: ["Open the app."], text: "Open the app.")
        XCTAssertEqual(CoachPresentation.kind(for: session), .coachCard)
        session.text = CoachText.generalFallback
        XCTAssertEqual(CoachPresentation.kind(for: session), .coachCard)
        XCTAssertTrue(CoachPresentation.showsCoachCard(session: session, error: nil))
        XCTAssertNil(CoachPresentation.reply(session: session, error: nil))
    }

    func testErrorsAndNoWordsKeepGuideCoachCard() throws {
        let guides: [HelpGuide] = try GuideLibrary.load()
        let guide = try XCTUnwrap(guides.first { $0.id == "whatsapp_send_photo" })
        let session = CoachSession(guide: guide, request: "Send a photo", person: nil,
                                   generalSteps: [], stepIndex: 2, text: guide.steps[2].instruction)
        let noWords = VoiceDiagnostics.message(for: VoiceInputError.noSpeechDetected)
        for message in ["Something went wrong.", noWords] {
            XCTAssertTrue(CoachPresentation.showsCoachCard(session: session, error: message))
            XCTAssertNil(CoachPresentation.reply(session: session, error: message))
        }
    }

    func testErrorsAndNoWordsKeepRealGeneralCoachCard() {
        let session = generalSession(steps: ["Open the app."], text: "Open the app.")
        let noWords = VoiceDiagnostics.message(for: VoiceInputError.noSpeechDetected)
        for message in ["Something went wrong.", noWords] {
            XCTAssertTrue(CoachPresentation.showsCoachCard(session: session, error: message))
            XCTAssertNil(CoachPresentation.reply(session: session, error: message))
        }
    }

    func testErrorsAndNoWordsWithoutCoachUseHomeReply() {
        let noWords = VoiceDiagnostics.message(for: VoiceInputError.noSpeechDetected)
        for message in ["Something went wrong.", noWords] {
            XCTAssertFalse(CoachPresentation.showsCoachCard(session: nil, error: message))
            XCTAssertEqual(CoachPresentation.reply(session: nil, error: message), message)
        }
    }

    func testErrorWithFallbackSessionUsesHomeReply() {
        let session = generalSession(steps: [CoachText.generalFallback], text: CoachText.generalFallback)
        let message = "Something went wrong."
        XCTAssertFalse(CoachPresentation.showsCoachCard(session: session, error: message))
        XCTAssertEqual(CoachPresentation.reply(session: session, error: message), message)
    }

    func testGuideUsesCoachCardAndWhatsAppOpenLinkWithoutChangingStep() throws {
        let guides: [HelpGuide] = try GuideLibrary.load()
        let guide = try XCTUnwrap(guides.first { $0.id == "whatsapp_send_photo" })
        let session = CoachSession(guide: guide, request: "Send a photo", person: nil,
                                   generalSteps: [], stepIndex: 0, text: guide.steps[0].instruction)
        XCTAssertEqual(CoachPresentation.kind(for: session), .coachCard)
        let launch = try XCTUnwrap(CoachPresentation.appLaunch(for: session))
        XCTAssertEqual(launch.app, "WhatsApp")
        XCTAssertEqual(launch.url.absoluteString, "whatsapp://")
        XCTAssertEqual(session.stepIndex, 0)
        XCTAssertEqual(session.text, guide.steps[0].instruction)
    }

    func testOpenAppIsHiddenAfterFirstStep() throws {
        let guides: [HelpGuide] = try GuideLibrary.load()
        let guide = try XCTUnwrap(guides.first { $0.id == "whatsapp_send_photo" })
        for index in guide.steps.indices.dropFirst() {
            let session = CoachSession(guide: guide, request: guide.title, person: nil,
                                       generalSteps: [], stepIndex: index, text: guide.steps[index].instruction)
            XCTAssertNil(CoachPresentation.appLaunch(for: session), "Step \(index + 1)")
        }
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
        XCTAssertEqual(VoiceOrbState.idle.inputLabels, ["Talk to NearMe", "Start listening", "Use voice"])
        XCTAssertEqual(VoiceOrbState.listening.inputLabels,
                       ["Listening... tap when you're done", "Stop listening"])
        for state in [VoiceOrbState.idle, .speaking, .listening] {
            let button = VoiceOrbButton(state: state, action: {})
            XCTAssertEqual(button.inputLabels, state.inputLabels)
        }
        XCTAssertEqual(VoiceOrbState.listening.symbolName, "waveform")
    }

    func testIdleOrbHasOneInstructionHintAndNoBottomAction() {
        let home = VoiceHomePresentation(activity: .ready, isHome: true,
                                         reply: nil, hasCompletedJourney: false)
        XCTAssertEqual(home.statusText, "Tap and tell me what you need help with")
        XCTAssertEqual(home.hintText, "Try: 'Help me play a song on YouTube'")
        XCTAssertFalse(home.showsCancel)
        XCTAssertFalse(home.showsStop)
        XCTAssertFalse(home.showsEndSession)
    }

    func testListeningHasOneStatusNoHintAndCancel() {
        let home = VoiceHomePresentation(activity: .listening, isHome: false,
                                         reply: nil, hasCompletedJourney: false)
        XCTAssertEqual(home.statusText, "Listening... tap when you're done")
        XCTAssertNil(home.hintText)
        XCTAssertTrue(home.showsCancel)
        XCTAssertFalse(home.showsStop)
    }

    func testCancelAppearsOnlyDuringListeningIncludingWaitingPromptsAndReplies() {
        for activity in VoiceActivity.allCases {
            for isHome in [true, false] {
                let replies: [String?] = [nil, "Where from?", "Did you mean Central?", CoachText.generalFallback]
                for reply in replies {
                    let presentation = VoiceHomePresentation(activity: activity, isHome: isHome,
                                                              reply: reply, hasCompletedJourney: false)
                    XCTAssertEqual(presentation.showsCancel, activity == .listening)
                }
            }
        }
    }

    func testLaunchAfterOnboardingUsesSessionAndOrbWithExistingDestinationsPreserved() {
        XCTAssertEqual(AppEntryPresentation.route(.welcome, hasCompletedOnboarding: false), .welcome)
        XCTAssertEqual(AppEntryPresentation.route(.howItWorks, hasCompletedOnboarding: false), .howItWorks)
        XCTAssertEqual(AppEntryPresentation.route(.session, hasCompletedOnboarding: false), .session)
        XCTAssertEqual(AppEntryPresentation.route(.welcome, hasCompletedOnboarding: true), .session)
        XCTAssertEqual(AppEntryPresentation.route(.goodMorning, hasCompletedOnboarding: true), .session)
        XCTAssertEqual(AppEntryPresentation.route(.session, hasCompletedOnboarding: true), .session)
        XCTAssertEqual(SessionScreen.resolve(isHome: true, showsCoach: false, hasPractice: false, isOpening: false), .voice)
        // A Home deep link takes precedence even if the engine still holds a guide.
        XCTAssertEqual(SessionScreen.resolve(isHome: true, showsCoach: true, hasPractice: false, isOpening: false), .voice)
        XCTAssertEqual(SessionScreen.resolve(isHome: false, showsCoach: true, hasPractice: false, isOpening: false), .coach)
        XCTAssertEqual(SessionScreen.resolve(isHome: false, showsCoach: false, hasPractice: true, isOpening: false), .practice)
        XCTAssertEqual(SessionScreen.resolve(isHome: false, showsCoach: false, hasPractice: false, isOpening: true), .opening)
        XCTAssertEqual(SessionScreen.resolve(isHome: false, showsCoach: false, hasPractice: false, isOpening: false), .voice)
    }

    func testMoreMenuContainsOwnerActionsAndDebugOnlyInDebugBuilds() {
        let titles: [String] = VoiceMenuAction.items.map { $0.title }
        var expected = ["Let NearMe see my screen", "Practice mode", "Type instead", "Set up Ask NearMe", "Settings"]
        #if DEBUG
        expected.append("Show debug info")
        #else
        XCTAssertFalse(titles.contains("Show debug info"))
        #endif
        XCTAssertEqual(titles, expected)
        XCTAssertEqual(VoiceMenuAction.screen.symbol, "rectangle.inset.filled.and.person.filled")
    }

    func testBothTypingSurfacesAllowBlankSongButRejectBlankOrdinaryAnswers() {
        for text in ["", "   ", "\n"] {
            XCTAssertTrue(TypedAnswerPresentation.canSend(text, canSubmit: true, isAwaitingSong: true))
            XCTAssertFalse(TypedAnswerPresentation.canSend(text, canSubmit: true, isAwaitingSong: false))
            XCTAssertFalse(TypedAnswerPresentation.canSend(text, canSubmit: false, isAwaitingSong: true))
        }
        XCTAssertTrue(TypedAnswerPresentation.canSend("Here comes the sun", canSubmit: true, isAwaitingSong: true))
        XCTAssertTrue(TypedAnswerPresentation.canSend("Central", canSubmit: true, isAwaitingSong: false))
        XCTAssertFalse(TypedAnswerPresentation.canSend("Central", canSubmit: false, isAwaitingSong: false))
    }

    func testPurpleAssetsAndAccentHaveAccessibleLightAndDarkVariants() throws {
        XCTAssertEqual(TTColor.accent, Color("AccentColor"))
        XCTAssertEqual(TTColor.violet, Color("AccentColor"))
        let light = UITraitCollection(userInterfaceStyle: .light)
        let dark = UITraitCollection(userInterfaceStyle: .dark)
        let accent = try XCTUnwrap(UIColor(named: "AccentColor"))
        try assertRGB(accent.resolvedColor(with: light), red: 110, green: 69, blue: 188)
        try assertRGB(accent.resolvedColor(with: dark), red: 191, green: 160, blue: 237)
        let plum = try XCTUnwrap(UIColor(named: "Plum"))
        let lavender = try XCTUnwrap(UIColor(named: "Lavender"))
        let pale = try XCTUnwrap(UIColor(named: "PaleLavender"))
        try assertRGB(plum.resolvedColor(with: light), red: 41, green: 27, blue: 67)
        try assertRGB(lavender.resolvedColor(with: light), red: 217, green: 200, blue: 242)
        try assertRGB(pale.resolvedColor(with: light), red: 240, green: 234, blue: 248)
        let onAccent = try XCTUnwrap(UIColor(named: "OnAccent"))
        for traits in [light, dark] {
            let foreground = try luminance(onAccent.resolvedColor(with: traits))
            let background = try luminance(accent.resolvedColor(with: traits))
            let contrast = (max(foreground, background) + 0.05) / (min(foreground, background) + 0.05)
            XCTAssertGreaterThanOrEqual(contrast, 4.5)
            let page = try luminance(pale.resolvedColor(with: traits))
            let text = try luminance(plum.resolvedColor(with: traits))
            let pageContrast = (max(text, page) + 0.05) / (min(text, page) + 0.05)
            XCTAssertGreaterThanOrEqual(pageContrast, 4.5)
        }
    }

    private func assertRGB(_ color: UIColor, red: CGFloat, green: CGFloat, blue: CGFloat) throws {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var alpha: CGFloat = 0
        XCTAssertTrue(color.getRed(&r, green: &g, blue: &b, alpha: &alpha))
        XCTAssertEqual(r, red / 255, accuracy: 0.001)
        XCTAssertEqual(g, green / 255, accuracy: 0.001)
        XCTAssertEqual(b, blue / 255, accuracy: 0.001)
        XCTAssertEqual(alpha, 1, accuracy: 0.001)
    }

    private func luminance(_ color: UIColor) throws -> Double {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var alpha: CGFloat = 0
        guard color.getRed(&r, green: &g, blue: &b, alpha: &alpha) else {
            throw NSError(domain: "UIPolishTests.Color", code: 1)
        }
        let components: [Double] = [Double(r), Double(g), Double(b)]
        let linear: [Double] = components.map { value in
            if value <= 0.04045 { return value / 12.92 }
            return pow((value + 0.055) / 1.055, 2.4)
        }
        return linear[0] * 0.2126 + linear[1] * 0.7152 + linear[2] * 0.0722
    }

    func testCompletedJourneyKeepsEndSessionUntilReturningHome() {
        let completed = VoiceHomePresentation(activity: .ready, isHome: false,
                                             reply: nil, hasCompletedJourney: true)
        XCTAssertTrue(completed.showsEndSession)
        let home = VoiceHomePresentation(activity: .ready, isHome: true,
                                        reply: nil, hasCompletedJourney: true)
        XCTAssertFalse(home.showsEndSession)
    }

    func testHomeStopAppearsOnlyDuringActualPlayback() {
        for activity in VoiceActivity.allCases {
            let presentation = VoiceHomePresentation(activity: activity, isHome: false,
                                                    reply: nil, hasCompletedJourney: false)
            XCTAssertEqual(presentation.showsStop, activity == .speaking, "\(activity)")
        }
        // The acknowledgement can have a speaking planner state while audio is still preparing.
        for outputActive in [false, true] {
            let preparing = activity(.speaking("I'll help you with that."), speaking: outputActive,
                                     preparing: true, starting: false, paused: false)
            let presentation = VoiceHomePresentation(activity: preparing, isHome: false,
                                                    reply: nil, hasCompletedJourney: false)
            XCTAssertFalse(presentation.showsStop)
        }
    }

    func testCoachIconTracksCurrentGuideStep() {
        let steps: [HelpGuide.Step] = [
            HelpGuide.Step(instruction: "Open the app.", uiLabelHint: "App", icon: "app"),
            HelpGuide.Step(instruction: "Choose a photo.", uiLabelHint: "Photo", icon: "photo"),
            HelpGuide.Step(instruction: "Review the photo.", uiLabelHint: "Review")
        ]
        var session = iconSession(steps: steps)
        XCTAssertEqual(CoachStepPresentation(session: session).icon, "app")
        session.stepIndex = 1
        XCTAssertEqual(CoachStepPresentation(session: session).icon, "photo")
        session.stepIndex = 2
        XCTAssertNil(CoachStepPresentation(session: session).icon)
    }

    func testCoachIconIsAbsentForMissingInvalidOrGeneralStep() {
        let steps: [HelpGuide.Step] = [
            HelpGuide.Step(instruction: "Open the app.", uiLabelHint: "App"),
            HelpGuide.Step(instruction: "Choose a photo.", uiLabelHint: "Photo", icon: "nearme.invalid.symbol"),
            HelpGuide.Step(instruction: "Review the photo.", uiLabelHint: "Review", icon: "")
        ]
        var session = iconSession(steps: steps)
        for index in [-1, 0, 1, 2, 3] {
            session.stepIndex = index
            XCTAssertNil(CoachStepPresentation(session: session).icon, "Index \(index)")
        }
        let general = generalSession(steps: ["Open the app."], text: "Open the app.")
        XCTAssertNil(CoachStepPresentation(session: general).icon)
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

    private func iconSession(steps: [HelpGuide.Step]) -> CoachSession {
        let guide = HelpGuide(id: "icon-test", title: "Photo help", app: "Photos",
                              appURLScheme: nil, aliases: [], steps: steps,
                              sourceNote: "Test fixture", lastChecked: "2026-10-24")
        return CoachSession(guide: guide, request: guide.title, person: nil,
                            generalSteps: [], stepIndex: 0, text: "Open the app.")
    }

    private func activity(_ state: TaskPlannerState, speaking: Bool, preparing: Bool,
                          starting: Bool, paused: Bool) -> VoiceActivity {
        VoiceActivity.resolve(plannerState: state, isSpeaking: speaking, isPreparing: preparing,
                              isStartingListening: starting, isPaused: paused)
    }
}
