import Foundation

public enum PrivacyFilter {
    private static let blockedBundleIDs: Set<String> = [
        "com.1password.1password", "com.agilebits.onepassword7", "com.bitwarden.desktop",
        "com.apple.keychainaccess", "com.apple.passwords", "com.dashlane.dashlanephonefinal"
    ]

    /// Check the original title before truncating or masking it. Reasons never echo UI text.
    public static func blockReason(bundleID: String, windowTitle: String) -> String? {
        if blockedBundleIDs.contains(bundleID.lowercased()) {
            return "This app may show passwords or other private information."
        }
        let pattern = #"(?<![\p{L}\p{M}\p{N}_])(?:passwords?|passcode|bank|banking|netbank|payment|card\s+number|otp|one-time\s+code)(?![\p{L}\p{M}\p{N}_])"#
        guard let keywords = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return "The screen's privacy could not be checked."
        }
        if keywords.firstMatch(in: windowTitle, range: NSRange(windowTitle.startIndex..., in: windowTitle)) != nil {
            return "This window may show financial or sign-in information."
        }
        return nil
    }

    /// Mask before truncation, so a contact spanning the length limit cannot leak a prefix.
    public static func sanitiseLabel(_ text: String) -> String {
        String(Pseudonymiser.mask(text).prefix(80))
    }

    /// Preserve traversal order and metadata; remove only secure controls.
    /// AXReader also rejects the secure subrole and descendants before reading labels.
    public static func sanitise(_ elements: [ScreenElement]) -> [ScreenElement] {
        elements.filter { $0.role != "AXSecureTextField" }.map { element in
            ScreenElement(role: element.role, label: sanitiseLabel(element.label),
                          frame: element.frame, isEnabled: element.isEnabled,
                          breadcrumb: sanitiseLabel(element.breadcrumb))
        }
    }
}
