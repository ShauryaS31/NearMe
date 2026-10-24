import Foundation
import NearMeCore
import Observation

@MainActor
@Observable
final class DebugViewModel {
    let target = TargetAppTracker()
    var goal = "make text bigger"
    private(set) var isBusy = false
    private(set) var accessibilityStatus = "Checking..."
    private(set) var modelStatus = "Checking..."
    private(set) var windowTitle = "—"
    private(set) var elementCount = 0
    private(set) var chosenElement = "—"
    private(set) var instruction = ""
    private(set) var status = "Select a target app, return here, then choose Next step."
    private(set) var error: String?
    private(set) var axMilliseconds: Double?
    private(set) var modelMilliseconds: Double?
    private(set) var totalMilliseconds: Double?
    private(set) var readDetails = ""
    private let overlay = Overlay()
    @ObservationIgnored private var request: Task<Void, Never>?
    @ObservationIgnored private var generation = 0

    func refreshAvailability() async {
        accessibilityStatus = await AXPermission.isTrusted() ? "Granted" : "Not granted"
        modelStatus = StepPlanner.unavailableReason.map { "Unavailable: \($0)" } ?? "Available"
    }

    func requestAccessibility() async {
        accessibilityStatus = await AXPermission.request() ? "Granted" : "Enable NearMe in Privacy & Security > Accessibility"
    }

    func clearRing() {
        generation += 1
        request?.cancel()
        request = nil
        isBusy = false
        overlay.clear()
        status = "Ring cleared."
    }

    func targetDidChange() {
        clearRing()
        resetResult()
        status = "Target changed. Choose Next step to read its focused window."
    }

    func nextStep() {
        clearRing()
        resetResult()
        guard let selectedTarget = target.app else {
            error = "Activate System Settings, then return to NearMe."
            return
        }
        let requestedGoal = goal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !requestedGoal.isEmpty else { error = "Enter a goal first."; return }
        let token = generation
        isBusy = true
        status = "Reading target window..."
        request = Task { await run(goal: requestedGoal, target: selectedTarget, token: token) }
    }

    private func resetResult() {
        error = nil
        windowTitle = "—"
        elementCount = 0
        chosenElement = "—"
        instruction = ""
        axMilliseconds = nil
        modelMilliseconds = nil
        totalMilliseconds = nil
        readDetails = ""
    }

    private func isCurrent(_ token: Int, _ selectedTarget: TargetApp) -> Bool {
        !Task.isCancelled && generation == token && target.app == selectedTarget
    }

    private func run(goal: String, target selectedTarget: TargetApp, token: Int) async {
        let start = ContinuousClock.now
        var axStart: ContinuousClock.Instant?
        var modelStart: ContinuousClock.Instant?
        defer {
            if generation == token {
                totalMilliseconds = milliseconds(start.duration(to: .now))
                isBusy = false
                request = nil
            }
        }
        do {
            let trusted = await AXPermission.isTrusted()
            guard isCurrent(token, selectedTarget) else { return }
            accessibilityStatus = trusted ? "Granted" : "Not granted"
            guard trusted else {
                await requestAccessibility()
                guard isCurrent(token, selectedTarget) else { return }
                error = "Grant Accessibility access, activate the target window, then try Next step again."
                status = "Accessibility permission required."
                return
            }
            axStart = .now
            let snapshot = try await AXReader.read(processID: selectedTarget.processID)
            guard isCurrent(token, selectedTarget) else { return }
            axMilliseconds = snapshot.milliseconds
            windowTitle = snapshot.windowTitle.isEmpty ? "(untitled)" : snapshot.windowTitle
            elementCount = snapshot.list.elements.count
            readDetails = "\(snapshot.visitedNodes) AX nodes visited" + (snapshot.wasTruncated ? " · partial read (budget or traversal limit)" : "")
            guard elementCount > 0 else {
                error = "No labelled, framed controls were available. Make the target window visible and try again."
                status = "Nothing to plan."
                return
            }
            status = "Choosing a step on device..."
            modelStatus = StepPlanner.unavailableReason.map { "Unavailable: \($0)" } ?? "Available"
            modelStart = .now
            let step = try await StepPlanner.plan(goal: goal, appName: selectedTarget.name,
                                                  windowTitle: snapshot.windowTitle, elements: snapshot.list)
            guard isCurrent(token, selectedTarget) else { return }
            if let modelStart { modelMilliseconds = milliseconds(modelStart.duration(to: .now)) }
            instruction = step.instruction
            // Completion/clarification never highlight, regardless of any accompanying index.
            if step.needsClarification {
                status = "Needs clarification. Adjust the goal or target window."
                return
            }
            if step.isGoalComplete {
                status = "Model reports the goal is complete."
                return
            }
            guard StepValidator.isValid(elementIndex: step.elementIndex, action: step.action.rawValue, in: snapshot.list) else {
                error = "Rejected model step: index \(step.elementIndex), action \(step.action.rawValue). The element must exist and be enabled."
                status = "Invalid step; no ring drawn."
                return
            }
            let element = snapshot.list.elements[step.elementIndex]
            chosenElement = "\(step.elementIndex): \(element.role) — \(element.label.isEmpty ? "(unlabelled)" : element.label)"
            guard step.action != .none else { status = "No action suggested; no ring drawn."; return }
            overlay.show(axFrame: element.frame)
            status = "Suggested action: \(step.action.rawValue). You perform the action."
        } catch {
            guard isCurrent(token, selectedTarget) else { return }
            if let modelStart {
                modelMilliseconds = milliseconds(modelStart.duration(to: .now))
            } else if let axStart, axMilliseconds == nil {
                axMilliseconds = milliseconds(axStart.duration(to: .now))
            }
            overlay.clear()
            self.error = error.localizedDescription
            status = "Step failed; no ring drawn."
        }
    }
}
