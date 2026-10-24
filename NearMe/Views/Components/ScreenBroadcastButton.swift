import SwiftUI
import Foundation
import ReplayKit
import UIKit
import OSLog

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
    @AppStorage("screenSharingExplanationSeen") private var explanationSeen = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Let NearMe see my screen").font(.title)
                    if explanationSeen {
                        pickerContent
                    } else {
                        Text(ScreenSharingCopy.explanation)
                        Button("Continue to screen sharing") { explanationSeen = true }
                            .buttonStyle(.borderedProminent)
                            .frame(minHeight: 44)
                    }
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
        .onAppear { ScreenBroadcastPresentation.logOpened() }
    }

    private var pickerContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Tap the broadcast button below, then Start Broadcast. You can stop using the screen recording control on your iPhone.")
            SystemScreenBroadcastPicker()
                .frame(width: 60, height: 60)
                .frame(maxWidth: .infinity)
            Text(ScreenSharingCopy.pickerFallback)
        }
    }
}

/// Direct native picker on the guide offer, with consent facts before the tap.
struct ScreenSharingOffer: View {
    let onNotNow: () -> Void
    @AppStorage("screenSharingExplanationSeen") private var explanationSeen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(ScreenSharingCopy.offer).font(.title2)
            if !explanationSeen { Text(ScreenSharingCopy.explanation) }
            SystemScreenBroadcastPicker()
                .frame(width: 60, height: 60)
                .accessibilityLabel("Let NearMe see my screen")
            Text(ScreenSharingCopy.pickerFallback)
            Button("Not now", action: onNotNow)
                .buttonStyle(.bordered)
                .frame(minHeight: 44)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(24)
        .onAppear { ScreenBroadcastPresentation.logOpened() }
        .onDisappear { explanationSeen = true }
    }
}

private enum ScreenBroadcastPresentation {
    static func logOpened() {
        Logger(subsystem: "au.nearme.ios", category: "broadcast").notice("Screen broadcast picker sheet opened")
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
    var song: String? = nil
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(status(at: context.date))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func status(at date: Date) -> String {
        let snapshot = AppGroupScreenSnapshotSource().latest()
        return ScreenDebugLine.make(snapshot: snapshot, song: song, now: date.timeIntervalSince1970)
    }
}
#endif
