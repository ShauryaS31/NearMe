import Foundation
import Combine

protocol ScreenSnapshotSource {
    nonisolated func latest() -> ScreenSnapshot?
}

nonisolated struct AppGroupScreenSnapshotSource: ScreenSnapshotSource {
    private let url: URL?
    init(url: URL? = nil) { self.url = url ?? SharedScreenBridge.snapshotURL }
    func latest() -> ScreenSnapshot? { url.flatMap { SharedScreenBridge.read(from: $0) } }
}

@MainActor
final class ScreenObserver: ObservableObject {
    @Published private(set) var snapshot: ScreenSnapshot?
    @Published private(set) var age: TimeInterval?
    @Published private(set) var changed = false
    var onPoll: (() -> Void)?
    private let source: any ScreenSnapshotSource
    private let now: () -> TimeInterval
    private var polling: Task<Void, Never>?
    private var previousTexts: Set<String>?

    init(source: any ScreenSnapshotSource, now: @escaping () -> TimeInterval) {
        self.source = source
        self.now = now
    }

    var canSee: Bool { age.map { $0 <= SharedScreenBridge.staleAfter } ?? false }

    func start() {
        guard polling == nil else { return }
        // Poll for start/stop too: the fresh file, not picker presentation, means sharing is on.
        polling = Task { [weak self] in
            while !Task.isCancelled {
                self?.poll()
                do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
            }
        }
    }

    func poll() {
        let latest = source.latest()
        age = latest?.age(at: now())
        let fresh = latest?.isFresh(at: now()) == true ? latest : nil
        changed = fresh.map { $0.textSet != previousTexts } ?? false
        previousTexts = fresh?.textSet
        // Drop recognised text from memory on stop/staleness too.
        snapshot = fresh
        onPoll?()
    }

    func stop() {
        polling?.cancel()
        polling = nil
        snapshot = nil
        age = nil
        previousTexts = nil
        changed = false
    }

    deinit { polling?.cancel() }
}
