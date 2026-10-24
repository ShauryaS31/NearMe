import SwiftUI

/// One voice surface for idle, capture, conversation prompts and non-step replies.
struct VoiceHomeContent<Actions: View>: View {
    let state: SessionDockState
    let presentation: VoiceHomePresentation
    let transcript: ConversationPresentation
    let onTalk: () -> Void
    let onCancel: () -> Void
    let onType: () -> Void
    @ViewBuilder var actions: () -> Actions
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var orbSize: CGFloat { dynamicTypeSize.isAccessibilitySize ? 144 : 208 }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: TTSpacing.sectionGap) {
                    voiceControls
                    if transcript.hasContent { ConversationTranscript(presentation: transcript) }
                    actions()
                }
                .padding(TTSpacing.screenInset)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(TTColor.paleLavender.ignoresSafeArea())
        .tint(TTColor.accent)
    }

    private var voiceControls: some View {
        VStack(spacing: TTSpacing.sectionGap) {
            VoiceOrbButton(state: state.micState, action: onTalk)
                .frame(width: orbSize, height: orbSize)
                .disabled(state.micDisabled)
            Text(presentation.statusText)
                .font(TTFont.title())
                .foregroundStyle(TTColor.plum)
                .fixedSize(horizontal: false, vertical: true)
            if let hint = presentation.hintText {
                Text(hint)
                    .font(TTFont.body())
                    .foregroundStyle(TTColor.plum)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(action: onType) {
                Label("Type instead", systemImage: "keyboard")
                    .font(TTFont.body())
                    .minimumTapTarget()
            }
            .buttonStyle(.borderless)
            if presentation.showsCancel {
                PrimaryButton(title: "Cancel", systemImage: "xmark", emphasis: .secondary, action: onCancel)
            }
        }
        .multilineTextAlignment(.center)
    }
}
