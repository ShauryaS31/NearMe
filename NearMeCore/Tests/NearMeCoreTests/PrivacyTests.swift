import CoreGraphics
import Foundation
import NearMeCore
import Testing

private func privacyElement(_ label: String, role: String = "AXButton",
                            enabled: Bool = true, breadcrumb: String = "Settings") -> ScreenElement {
    ScreenElement(role: role, label: label, frame: CGRect(x: 10, y: 20, width: 80, height: 30),
                  isEnabled: enabled, breadcrumb: breadcrumb)
}

@Test func privacyBlocksEverySpecifiedBundleCaseInsensitivelyAndExactly() {
    for bundle in ["com.1password.1password", "com.agilebits.onepassword7", "com.bitwarden.desktop",
                   "com.apple.keychainaccess", "com.apple.Passwords", "com.dashlane.dashlanephonefinal"] {
        #expect(PrivacyFilter.blockReason(bundleID: bundle, windowTitle: "") != nil)
        #expect(PrivacyFilter.blockReason(bundleID: bundle.uppercased(), windowTitle: "Settings") != nil)
        #expect(PrivacyFilter.blockReason(bundleID: bundle + ".helper", windowTitle: "Settings") == nil)
        #expect(PrivacyFilter.blockReason(bundleID: "prefix." + bundle, windowTitle: "Settings") == nil)
    }
    #expect(PrivacyFilter.blockReason(bundleID: "com.apple.systempreferences", windowTitle: "Display") == nil)
    #expect(PrivacyFilter.blockReason(bundleID: "", windowTitle: "") == nil)
}

@Test func privacyBlocksWholeTitleWordsAndPhrases() {
    for keyword in ["password", "passwords", "passcode", "bank", "banking", "netbank",
                    "payment", "card number", "otp", "one-time code"] {
        #expect(PrivacyFilter.blockReason(bundleID: "browser", windowTitle: "Account — (\(keyword.uppercased()))") != nil)
    }
    for title in ["Bankstown", "Riverbank", "Banker", "Hotpot", "PaymentStatus", "passwordless",
                  "passcodes", "card numbers", "one-time codec", "bank_account", "ébank", "bank2"] {
        #expect(PrivacyFilter.blockReason(bundleID: "browser", windowTitle: title) == nil)
    }
    #expect(PrivacyFilter.blockReason(bundleID: "browser", windowTitle: "Enter card\nnumber") != nil)
    // Check the original title, even when the sensitive keyword is beyond the label cap.
    #expect(PrivacyFilter.blockReason(bundleID: "browser", windowTitle: String(repeating: "x", count: 100) + " Payment") != nil)
    let reason = PrivacyFilter.blockReason(bundleID: "browser", windowTitle: "Bank — person@example.com")
    #expect(reason != nil)
    #expect(reason?.contains("person@example.com") == false)
}

@Test func pseudonymiserMasksEmailAndTelephoneWithoutShiftingUnicodeRanges() {
    let raw = "👋 Email alex@example.com; call +1 (415) 555-2671; alex@example.com"
    let masked = Pseudonymiser.mask(raw)
    #expect(masked == "👋 Email [email]; call [phone]; [email]")
    #expect(Pseudonymiser.mask(masked) == masked)
    #expect(Pseudonymiser.mask("Call +61 412 345 678") == "Call [phone]")
    #expect(Pseudonymiser.mask("") == "")
    #expect(Pseudonymiser.mask("Display settings https://example.com") == "Display settings https://example.com")
}

@Test func privacyRemovesSecureFieldsAndMasksLabelsAndBreadcrumbs() {
    let normal = privacyElement("Email alex@example.com", role: "AXTextField", enabled: false,
                                breadcrumb: "Call +1 (415) 555-2671")
    let secure = privacyElement("Never include this", role: "AXSecureTextField")
    let output = PrivacyFilter.sanitise([secure, normal, secure])
    #expect(output.count == 1)
    #expect(output.first?.label == "Email [email]")
    #expect(output.first?.breadcrumb == "Call [phone]")
    #expect(output.first?.role == normal.role)
    #expect(output.first?.frame == normal.frame)
    #expect(output.first?.isEnabled == false)
    #expect(PrivacyFilter.sanitise([secure]).isEmpty)
    #expect(PrivacyFilter.sanitise([]).isEmpty)
}

@Test func privacyTruncatesTo80CharactersAfterMasking() {
    let grapheme = "👨‍👩‍👧‍👦"
    let eighty = String(repeating: grapheme, count: 80)
    #expect(PrivacyFilter.sanitiseLabel(eighty) == eighty)
    #expect(PrivacyFilter.sanitiseLabel(eighty + grapheme) == eighty)
    #expect(PrivacyFilter.sanitiseLabel("Display") == "Display")
    #expect(PrivacyFilter.sanitiseLabel("") == "")
    let prefix = String(repeating: "x", count: 75) + " "
    let result = PrivacyFilter.sanitiseLabel(prefix + "alex@example.com")
    #expect(result == prefix + "[ema")
    #expect(!result.contains("alex"))
    let output = PrivacyFilter.sanitise([privacyElement(eighty + grapheme, breadcrumb: eighty + grapheme)])
    #expect(output.first?.label == eighty)
    #expect(output.first?.breadcrumb == eighty)
}

@Test func privacyKeepsOrderEmptyLabelsDisabledDuplicatesAndUnrecognisedRoles() {
    let items = [privacyElement(""), privacyElement(" ", enabled: false),
                 privacyElement("Custom", role: "AXCustom"), privacyElement("Custom", role: "AXCustom")]
        + (0..<125).map { privacyElement("Item \($0)") }
    #expect(PrivacyFilter.sanitise(items) == items)
    var withSecure = items
    withSecure.insert(privacyElement("Secret", role: "AXSecureTextField"), at: 2)
    #expect(PrivacyFilter.sanitise(withSecure) == items)
}

@Test func privacySanitisesBeforeElementListCapAndPromptRendering() {
    let secure = privacyElement("Secret sentinel", role: "AXSecureTextField")
    let contacts = privacyElement("alex@example.com", breadcrumb: "+1 (415) 555-2671")
    let raw = [secure, contacts] + (0..<119).map { privacyElement("Item \($0)") }
    let list = ElementList(PrivacyFilter.sanitise(raw))
    #expect(list.elements.count == 120)
    #expect(list.elements.last?.label == "Item 118")
    let prompt = list.prompt(goal: "Help", appName: "Settings",
                             windowTitle: PrivacyFilter.sanitiseLabel("alex@example.com"))
    #expect(!prompt.contains("Secret sentinel"))
    #expect(!prompt.contains("alex@example.com"))
    #expect(!prompt.contains("415"))
    #expect(prompt.contains("0: AXButton | \"[email]\""))
    #expect(prompt.contains("parent: \"[phone]\""))
}
