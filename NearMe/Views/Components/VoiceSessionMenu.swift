import SwiftUI

enum VoiceMenuAction: String, Identifiable {
    case screen, practice, type, settings, endSession
    #if DEBUG
    case debug
    #endif

    var id: Self { self }

    static var items: [Self] {
        var items: [Self] = [.screen, .practice, .type, .settings]
        #if DEBUG
        items.append(.debug)
        #endif
        return items
    }

    var title: String {
        switch self {
        case .screen: return "Let NearMe see my screen"
        case .practice: return "Practice mode"
        case .type: return "Type instead"
        case .settings: return "Settings"
        case .endSession: return "End session"
        #if DEBUG
        case .debug: return "Show debug info"
        #endif
        }
    }

    var symbol: String {
        switch self {
        case .screen: return "rectangle.inset.filled.and.person.filled"
        case .practice: return "tram.fill"
        case .type: return "keyboard"
        case .settings: return "gearshape"
        case .endSession: return "xmark.circle"
        #if DEBUG
        case .debug: return "ladybug"
        #endif
        }
    }
}

enum VoiceSessionSheet: String, Identifiable {
    case screen, settings
    var id: Self { self }
}

struct VoiceSessionMenu: View {
    let showsEndSession: Bool
    let onSelect: (VoiceMenuAction) -> Void

    var body: some View {
        Menu {
            ForEach(VoiceMenuAction.items) { item in
                Button { onSelect(item) } label: {
                    Label(item.title, systemImage: item.symbol)
                }
            }
            if showsEndSession {
                Button { onSelect(.endSession) } label: {
                    Label(VoiceMenuAction.endSession.title, systemImage: VoiceMenuAction.endSession.symbol)
                }
            }
        } label: {
            Label("More", systemImage: "ellipsis.circle")
                .labelStyle(.iconOnly)
                .font(.title2)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("More")
        .tint(TTColor.accent)
    }
}

struct VoiceSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Voice and accessibility") {
                    Text("NearMe follows your iPhone's text size, appearance and Reduce Motion settings.")
                    Text("More settings coming soon.")
                }
            }
            .font(TTFont.body())
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .tint(TTColor.accent)
    }
}

/// Both typing surfaces use the P07e blank-song exception, including whitespace.
enum TypedAnswerPresentation {
    static func canSend(_ text: String, canSubmit: Bool, isAwaitingSong: Bool) -> Bool {
        canSubmit && (isAwaitingSong || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}
