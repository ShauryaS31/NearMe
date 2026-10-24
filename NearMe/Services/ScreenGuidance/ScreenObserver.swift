import Foundation
import Combine

nonisolated protocol ScreenSnapshotSource {
    nonisolated func latest() -> ScreenSnapshot?
}

nonisolated struct AppGroupScreenSnapshotSource: ScreenSnapshotSource {
    private let url: URL?
    private let now: () -> TimeInterval
    init(url: URL? = nil, now: (() -> TimeInterval)? = nil) {
        self.url = url ?? SharedScreenBridge.snapshotURL
        self.now = now ?? { Date().timeIntervalSince1970 }
    }
    func latest() -> ScreenSnapshot? {
        guard let url, let snapshot = SharedScreenBridge.read(from: url) else { return nil }
        if let age = snapshot.age(at: now()), age > 10 {
            // Re-read before cleanup in case the extension refreshed during the first read.
            if SharedScreenBridge.read(from: url)?.timestamp == snapshot.timestamp {
                try? SharedScreenBridge.delete(at: url)
            }
            return nil
        }
        return snapshot
    }
}

@MainActor
final class ScreenObserver: ObservableObject {
    @Published private(set) var snapshot: ScreenSnapshot?
    @Published private(set) var age: TimeInterval?
    @Published private(set) var changed = false
    var onPoll: (() -> Void)?
    private let source: any ScreenSnapshotSource
    private let now: () -> TimeInterval
    private let recheckWait: (TimeInterval) async throws -> Void
    private var polling: Task<Void, Never>?
    private var previousTexts: Set<String>?
    private var activeSince: TimeInterval?

    /// The frozen observation is evaluated at activation, while live file age
    /// independently determines whether sharing is still on.
    var observationTime: TimeInterval { activeSince ?? now() }
    var isHoldingObservation: Bool { activeSince != nil }

    func sceneBecameActive() {
        guard activeSince == nil else { return }
        activeSince = now()
        poll()
    }

    func sceneBecameInactive() { activeSince = nil }

    init(source: any ScreenSnapshotSource, now: @escaping () -> TimeInterval,
         recheckWait: ((TimeInterval) async throws -> Void)? = nil) {
        self.source = source
        self.now = now
        self.recheckWait = recheckWait ?? { try await Task.sleep(for: .seconds($0)) }
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
        let time = now()
        age = latest?.age(at: time)
        var fresh = latest?.isFresh(at: time) == true ? latest : nil
        if let activeSince, let candidate = fresh, candidate.timestamp > activeSince {
            fresh = snapshot
        }
        changed = fresh.map { $0.textSet != previousTexts } ?? false
        previousTexts = fresh?.textSet
        // Drop recognised text from memory on stop/staleness too.
        snapshot = fresh
        onPoll?()
    }

    /// Request-time read, then at most 1.5 s for a newer capture. When NearMe is
    /// visible, preserve P13b's retained external page instead of interpreting our UI.
    func freshForRecheck() async throws -> ScreenSnapshot? {
        let previous = snapshot?.timestamp
        poll()
        if isHoldingObservation { return snapshot }
        for _ in 0..<15 {
            if let snapshot, snapshot.timestamp != previous { return snapshot }
            try await recheckWait(0.1)
            try Task.checkCancellation()
            poll()
        }
        return snapshot
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
