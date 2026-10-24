import ActivityKit
import SwiftUI
import UIKit

struct AskWidgetSetupView: View {
    @StateObject private var permissions = PermissionsManager()
    @State private var checking = false
    @State private var message: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Ask from your Home Screen").font(.title)
                    Text("Tap Ask NearMe and wait for Listening before speaking. NearMe answers and listens again, so you can keep talking. Say Stop or choose Stop to finish. Finish sends your current words without ending the conversation.")
                    Text("After a quiet pause, NearMe asks once if you still need help. Say wait or one minute for more time. If you stay quiet, it says goodbye and stops. Each conversation is limited to ten minutes.")
                    Text("This widget understands English using on-device speech recognition. Your microphone stays active during the conversation, including pauses, but NearMe ignores audio while it speaks or other audio plays. A recording indicator stays visible. Live Activities must be enabled in Settings.")
                    Text("Add the small Ask NearMe widget using Edit on your Home Screen. The widget stays there when you ask. Opening this help screen stops a current recording.")
                    if let message { Text(message).accessibilityAddTraits(.isStaticText) }
                    Button {
                        checking = true
                        Task {
                            await permissions.requestAll()
                            let ready = UserDefaults.standard.bool(forKey: AskWidgetStore.onboardingKey)
                                && permissions.isFullyAuthorized && AskNearMeCapture.availableRecognizer() != nil
                                && ActivityAuthorizationInfo().areActivitiesEnabled
                            UserDefaults.standard.set(ready, forKey: AskWidgetStore.setupKey)
                            AskWidgetStore.write(AskWidgetState(phase: ready ? .ready : .setup))
                            message = ready ? "Ready. Return to your Home Screen and tap Ask NearMe."
                                : "Voice access, on-device recognition or Live Activities is unavailable. Check Settings, or close this screen to type instead."
                            checking = false
                        }
                    } label: { Label(checking ? "Checking" : "Continue", systemImage: "mic") }
                        .buttonStyle(.borderedProminent).disabled(checking)
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        Link(destination: url) { Label("Open Settings", systemImage: "gearshape") }
                    }
                    Button { dismiss() } label: { Label("Close", systemImage: "xmark") }
                }.font(.body).padding()
            }.navigationTitle("Ask NearMe")
        }
    }
}
