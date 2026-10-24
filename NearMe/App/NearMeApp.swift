// Adapted from a prior prototype, used with permission.

import SwiftUI

@main
struct NearMeApp: App {
    @StateObject private var coordinator = AppCoordinator()

    init() {
        // Also runs on a background intent launch; no coach engine is required.
        CoachActivityLifecycle.reconcile(store: CoachProgressStore(), guides: CoachActivityGuide.bundled(),
                                         updater: CoachActivityUpdater.shared)
        #if DEBUG
        _ = GuideLibrary.bundled()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(coordinator)
                .onOpenURL { coordinator.handleOpenURL($0) }
        }
    }
}
