import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = DebugViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("NearMe · Core loop spike")
                    .font(.title.bold())
                TextField("What would you like to do?", text: $model.goal)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { if !model.isBusy { model.nextStep() } }
                HStack {
                    Button("Next step") { model.nextStep() }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.isBusy || model.goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Clear ring") { model.clearRing() }
                    if model.isBusy { ProgressView().controlSize(.small) }
                }
                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 10) {
                    row("Target app", model.target.app?.name ?? "None - activate System Settings first")
                    row("Window", model.windowTitle)
                    row("Accessibility", model.accessibilityStatus)
                    row("Foundation Models", model.modelStatus)
                    row("Elements (capped)", String(model.elementCount))
                    row("Chosen element", model.chosenElement)
                    row("AX read", timing(model.axMilliseconds))
                    row("Model", timing(model.modelMilliseconds))
                    row("Total latency", timing(model.totalMilliseconds))
                }
                if !model.readDetails.isEmpty {
                    Text(model.readDetails).font(.caption).foregroundStyle(.secondary)
                }
                if !model.instruction.isEmpty {
                    Text(model.instruction).font(.title3).textSelection(.enabled)
                }
                Text(model.status).foregroundStyle(.secondary)
                if let error = model.error {
                    Text(error).foregroundStyle(.red).textSelection(.enabled)
                }
                Button("Open Accessibility Settings") {
                    Task { await model.requestAccessibility() }
                }
                Text("Activate the app to guide, then return here. NearMe remembers it and only points; you make every click. Readings are manual for this spike.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 620, minHeight: 540)
        .task(id: scenePhase) { await model.refreshAvailability() }
        .onChange(of: model.target.app) { model.targetDidChange() }
        .onDisappear { model.clearRing() }
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func timing(_ value: Double?) -> String {
        value.map { String(format: "%.0f ms", $0) } ?? "-"
    }
}
