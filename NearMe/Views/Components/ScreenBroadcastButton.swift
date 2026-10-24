import SwiftUI
import Foundation
import ReplayKit
import UIKit

struct ScreenBroadcastButton: View {
    @State private var showsPicker = false

    var body: some View {
        Button { showsPicker = true } label: {
            Label("Let NearMe see my screen", systemImage: "rectangle.inset.filled.and.person.filled")
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 44)
        }
        .buttonStyle(.bordered)
        .sheet(isPresented: $showsPicker) {
            ScreenBroadcastPickerSheet()
        }
    }
}

private struct ScreenBroadcastPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Try the screen connection").font(.title)
                    Text("This test counts screen updates to check the connection. NearMe does not read the words, save pictures or sound, or send your screen anywhere.")
                    Text("Tap the broadcast button below, then Start Broadcast. You can stop using the screen recording control on your iPhone.")
                    SystemScreenBroadcastPicker()
                        .frame(width: 60, height: 60)
                        .frame(maxWidth: .infinity)
                }
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
        }
    }
}

private struct SystemScreenBroadcastPicker: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        picker.preferredExtension = "au.nearme.ios.broadcast"
        picker.showsMicrophoneButton = false
        return picker
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}

#if DEBUG
struct ScreenBroadcastDebugLine: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(status(at: context.date))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func status(at date: Date) -> String {
        let heartbeat = SharedScreenBridge.heartbeatURL.flatMap { SharedScreenBridge.read(from: $0) }
        return SharedScreenBridge.debugLine(heartbeat: heartbeat, now: date)
    }
}
#endif
