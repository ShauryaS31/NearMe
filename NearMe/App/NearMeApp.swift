// Adapted from a prior prototype, used with permission.

import SwiftUI

@main
struct NearMeApp: App {
    @StateObject private var coordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(coordinator)
        }
    }
}
