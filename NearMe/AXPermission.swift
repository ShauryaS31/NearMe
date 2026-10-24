import AppKit
import ApplicationServices

enum AXPermission {
    static func isTrusted(prompt: Bool = false) async -> Bool {
        await Task.detached(priority: .userInitiated) {
            // The key's documented string avoids passing a CF object across isolation domains.
            AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": prompt] as CFDictionary)
        }.value
    }

    @MainActor
    static func request() async -> Bool {
        let trusted = await isTrusted(prompt: true)
        if !trusted, let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        return trusted
    }
}
