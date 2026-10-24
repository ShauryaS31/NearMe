import SwiftUI
import UIKit

struct CoachView: View {
    @ObservedObject var engine: TaskPlannerEngine
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsHelp = false

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ScrollView {
                    if let session = engine.coach {
                        CoachStepContent(session: session, onCommand: command)
                            .id(session.stepIndex)
                            .transition(.opacity)
                    }
                }
                .animation(stepAnimation, value: engine.coach?.stepIndex)
                if let session = engine.coach {
                    SessionDock(engine: engine, instruction: session.text,
                                targetLabel: session.guide?.steps[session.stepIndex].uiLabelHint,
                                availableHeight: geometry.size.height)
                }
            }
        }
        .background(TTColor.groupedBackground)
        .tint(TTColor.accent)
        .sheet(isPresented: $showsHelp) {
            CoachHelpSheet(engine: engine)
                .presentationDetents([.large])
        }
        .onChange(of: engine.coach?.id) { _, id in
            if id == nil { showsHelp = false }
        }
    }

    private func command(_ command: CoachCommand) {
        if command == .stuck { showsHelp = true }
        engine.coachCommand(command)
    }

    private var stepAnimation: Animation? {
        if reduceMotion { return nil }
        return .easeInOut(duration: 0.2)
    }
}

/// Presentation shared by the card and its default-run assertions.
struct CoachStepPresentation {
    let session: CoachSession

    var title: String {
        if let guide = session.guide { return guide.title }
        return session.request.isEmpty ? "Your next step" : session.request
    }
    var countText: String { "Step \(session.stepIndex + 1) of \(session.count)" }
    var hasKnownTotal: Bool { session.count > 0 }
    var completedSteps: Double { Double(session.stepIndex) }
    var totalSteps: Double { Double(session.count) }
    var doneTitle: String { "Done" }
    var icon: String? {
        guard let guide = session.guide, guide.steps.indices.contains(session.stepIndex),
              let name = guide.steps[session.stepIndex].icon,
              UIImage(systemName: name) != nil else { return nil }
        return name
    }

    var instruction: AttributedString {
        var text = AttributedString(session.text)
        if let label = session.guide?.steps[session.stepIndex].uiLabelHint,
           let range = text.range(of: label) {
            text[range].swiftUI.font = .title2.bold()
        }
        return text
    }
}

struct CoachStepContent: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title2) private var scaledIconSize: CGFloat = 60
    let session: CoachSession
    let onCommand: (CoachCommand) -> Void

    private var presentation: CoachStepPresentation { CoachStepPresentation(session: session) }

    private var iconSize: CGFloat {
        if dynamicTypeSize.isAccessibilitySize { return min(scaledIconSize, 44) }
        return min(scaledIconSize, 72)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TTSpacing.sectionGap) {
            Text(presentation.title)
                .font(TTFont.headline())
                .accessibilityAddTraits(.isHeader)
            if session.isGeneral {
                Text("General guidance: your screen may look different")
                    .font(TTFont.body())
                    .foregroundStyle(TTColor.textSecondary)
            }
            if presentation.hasKnownTotal {
                progress
            }
            stepIcon
            Text(presentation.instruction)
                .font(TTFont.title())
                .fixedSize(horizontal: false, vertical: true)
            if let launch = CoachPresentation.appLaunch(for: session) {
                openApp(launch)
            }
            PrimaryButton(title: presentation.doneTitle, systemImage: "checkmark") { onCommand(.next) }
            AdaptiveButtonRow {
                PrimaryButton(title: "Repeat", systemImage: "arrow.counterclockwise", emphasis: .secondary) {
                    onCommand(.repeatStep)
                }
                PrimaryButton(title: "I'm stuck", systemImage: "questionmark.circle", emphasis: .secondary) {
                    onCommand(.stuck)
                }
            }
        }
        .padding(TTSpacing.cardPadding)
        .frame(maxWidth: 600, alignment: .leading)
        .background(TTColor.readingSurface,
                    in: RoundedRectangle(cornerRadius: TTRadius.card, style: .continuous))
        .padding(TTSpacing.screenInset)
        .frame(maxWidth: .infinity)
        .tint(TTColor.accent)
    }

    @ViewBuilder private var stepIcon: some View {
        if let icon = presentation.icon {
            Image(systemName: icon)
                .font(.system(size: iconSize))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(TTColor.accent)
                .accessibilityHidden(true)
        }
    }

    private func openApp(_ launch: CoachAppLink) -> some View {
        AdaptiveButtonRow {
            Text("Open \(launch.app), then return here when you're ready. Tap Done after you finish this step.")
                .font(TTFont.body())
                .fixedSize(horizontal: false, vertical: true)
            PrimaryButton(title: "Open \(launch.app)", systemImage: "arrow.up.forward.app", emphasis: .secondary) {
                openURL(launch.url)
            }
        }
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: TTSpacing.relatedGap) {
            Text(presentation.countText).font(TTFont.body())
            ProgressView(value: presentation.completedSteps, total: presentation.totalSteps)
                .accessibilityLabel("Completed steps")
                .accessibilityValue("\(session.stepIndex) of \(session.count)")
        }
    }
}

private struct CoachHelpSheet: View {
    @ObservedObject var engine: TaskPlannerEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScreenScaffold {
                VStack(alignment: .leading, spacing: TTSpacing.sectionGap) {
                    if engine.plannerState == .thinking || engine.isPreparingSpeech {
                        VoiceStateRow(activity: .preparing)
                    }
                    if let session = engine.coach {
                        Text(session.text)
                            .font(TTFont.title())
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(TTSpacing.cardPadding)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(TTColor.readingSurface,
                                        in: RoundedRectangle(cornerRadius: TTRadius.card, style: .continuous))
                    }
                    PrimaryButton(title: "Repeat", systemImage: "arrow.counterclockwise", emphasis: .secondary) {
                        engine.coachCommand(.repeatStep)
                    }
                    PrimaryButton(title: "Slower", systemImage: "tortoise", emphasis: .secondary) {
                        engine.coachCommand(.slower)
                    }
                    PrimaryButton(title: "Stop", systemImage: "stop.fill", emphasis: .secondary,
                                  action: engine.stopSessionSpeech)
                    PrimaryButton(title: "Close", systemImage: "xmark", emphasis: .secondary) { dismiss() }
                }
            }
            .navigationTitle("I'm stuck")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Label("Close", systemImage: "xmark") }
                }
            }
        }
        .tint(TTColor.accent)
    }
}
