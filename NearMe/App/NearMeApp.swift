// Adapted from a prior prototype, used with permission.

import SwiftUI

@main
struct NearMeApp: App {
    @StateObject private var coordinator = AppCoordinator()

    init() {
        #if DEBUG
        _ = GuideLibrary.bundled()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(coordinator)
        }
    }
}
