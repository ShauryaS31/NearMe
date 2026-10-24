import ApplicationServices
import Foundation
import FoundationModels
import NearMeCore
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var accessibilityStatus = "Checking..."
    @State private var modelStatus = "Checking..."

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("NearMe")
                .font(.largeTitle.bold())
            Text(Scaffold.message)
                .foregroundStyle(.secondary)
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 12) {
                GridRow {
                    Text("Accessibility trusted")
                    Text(accessibilityStatus)
                }
                GridRow {
                    Text("Foundation Models")
                    Text(modelStatus)
                }
                GridRow {
                    Text("macOS version")
                    Text(ProcessInfo.processInfo.operatingSystemVersionString)
                }
            }
            Text("This scaffold shows system status. Guidance is coming next.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(minWidth: 500, minHeight: 260, alignment: .topLeading)
        .task(id: scenePhase) {
            await refreshStatus()
        }
    }

    @MainActor
    private func refreshStatus() async {
        switch SystemLanguageModel.default.availability {
        case .available:
            modelStatus = "Available"
        case .unavailable(.deviceNotEligible):
            modelStatus = "Unavailable: this Mac is not eligible"
        case .unavailable(.appleIntelligenceNotEnabled):
            modelStatus = "Unavailable: turn on Apple Intelligence"
        case .unavailable(.modelNotReady):
            modelStatus = "Unavailable: model is not ready"
        case .unavailable:
            modelStatus = "Unavailable"
        @unknown default:
            modelStatus = "Unknown availability"
        }

        // Check local trust off the main thread, with a one-second UI wait budget.
        // The synchronous system call cannot be interrupted, but late results are ignored.
        let (results, continuation) = AsyncStream<Bool>.makeStream()
        let check = Task.detached(priority: .utility) {
            continuation.yield(AXIsProcessTrusted())
            continuation.finish()
        }
        let timeout = Task {
            try? await Task.sleep(for: .seconds(1))
            continuation.finish()
        }
        defer {
            check.cancel()
            timeout.cancel()
        }
        var iterator = results.makeAsyncIterator()
        let trusted = await iterator.next()
        guard !Task.isCancelled else { return }
        accessibilityStatus = trusted.map { $0 ? "Yes" : "No" } ?? "Check timed out"
    }
}
