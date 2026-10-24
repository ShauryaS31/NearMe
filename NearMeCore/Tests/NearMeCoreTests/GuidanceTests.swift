import CoreGraphics
import Foundation
import NearMeCore
import Testing

private func element(_ label: String = "Display", enabled: Bool = true) -> ScreenElement {
    ScreenElement(role: "AXButton", label: label, frame: CGRect(x: 20, y: 30, width: 100, height: 40),
                  isEnabled: enabled, breadcrumb: "Settings > Accessibility")
}

@Test func elementSnapshotAndRendering() {
    let item = element()
    #expect(item.role == "AXButton")
    #expect(item.label == "Display")
    #expect(item.frame == CGRect(x: 20, y: 30, width: 100, height: 40))
    #expect(item.isEnabled)
    #expect(item.breadcrumb == "Settings > Accessibility")
    let list = ElementList([item, element("Text size", enabled: false)])
    #expect(list.rendered() == "0: AXButton | \"Display\" | enabled | parent: \"Settings > Accessibility\"\n1: AXButton | \"Text size\" | disabled | parent: \"Settings > Accessibility\"")
}

@Test func emptyAndAtCapacityListsRetainEmptyLabels() {
    #expect(ElementList([]).rendered().isEmpty)
    let items = (0..<120).map { element($0 == 5 ? "" : "Item \($0)") }
    #expect(ElementList.maximumCount == 120)
    #expect(ElementList(items).elements == items)
}

@Test func capDropsEmptyLabelsBeforeTruncatingAndReindexes() {
    var items = (0..<125).map { element("Item \($0)") }
    items[0] = element("")
    items[60] = element(" \n ")
    let list = ElementList(items)
    #expect(list.elements.count == 120)
    #expect(list.elements == Array(items.filter { !$0.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.prefix(120)))
    #expect(list.elements.first?.label == "Item 1")
    #expect(list.elements.last?.label == "Item 121")
    #expect(list.rendered().split(separator: "\n").enumerated().allSatisfy { index, line in line.hasPrefix("\(index): ") })
    #expect(ElementList(Array(repeating: element(""), count: 121)).elements.isEmpty)
}

@Test func capPreservesFirst120InTraversalOrder() {
    let items = (0..<130).map { element("Item \($0)") }
    #expect(ElementList(items).elements == Array(items.prefix(120)))
}

@Test func promptIncludesGroundingAndEscapesUIData() {
    let list = ElementList([element("Text\n\"size\"")])
    let prompt = list.prompt(goal: "make text bigger", appName: "System Settings", windowTitle: "Accessibility")
    #expect(prompt.contains("Goal: \"make text bigger\""))
    #expect(prompt.contains("App: \"System Settings\""))
    #expect(prompt.contains("Window: \"Accessibility\""))
    #expect(prompt.contains(list.rendered()))
    #expect(prompt.contains("Pick only an index from this list"))
    #expect(prompt.contains("needsClarification"))
    #expect(list.rendered().contains("\"Text \\\"size\\\"\""))
    #expect(list.rendered().split(separator: "\n").count == 1)
    #expect(ElementList([element(String(repeating: "x", count: 200))]).rendered().contains(String(repeating: "x", count: 160)))
    #expect(!ElementList([element(String(repeating: "x", count: 200))]).rendered().contains(String(repeating: "x", count: 161)))
}

@Test func validatorAcceptsOnlyEnabledInRangeAllowedActions() {
    let list = ElementList([element(), element("Disabled", enabled: false)])
    for action in ["click", "scroll", "none"] {
        #expect(StepValidator.isValid(elementIndex: 0, action: action, in: list))
    }
    #expect(!StepValidator.isValid(elementIndex: 2, action: "click", in: list))
    #expect(!StepValidator.isValid(elementIndex: -1, action: "click", in: list))
    #expect(!StepValidator.isValid(elementIndex: 1, action: "click", in: list))
    #expect(!StepValidator.isValid(elementIndex: 0, action: "type", in: list))
    #expect(!StepValidator.isValid(elementIndex: 0, action: "click", in: ElementList([])))
}
