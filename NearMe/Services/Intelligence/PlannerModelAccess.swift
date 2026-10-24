import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

nonisolated enum ModelUnavailability: String, Sendable {
    case deviceNotEligible, appleIntelligenceNotEnabled, modelNotReady, other

    var label: String {
        switch self {
        case .deviceNotEligible: return "device not eligible"
        case .appleIntelligenceNotEnabled: return "Apple Intelligence off"
        case .modelNotReady: return "model not ready"
        case .other: return "model unavailable"
        }
    }
}

nonisolated enum PlannerModelAvailability: Equatable, Sendable {
    case available
    case unavailable(ModelUnavailability)
}

nonisolated enum ModelFallbackReason: Equatable, Sendable {
    case unavailable(ModelUnavailability)
    case timeout, rejected, error

    var label: String {
        switch self {
        case .unavailable(let reason): return reason.label
        case .timeout: return "timeout"
        case .rejected: return "rejected"
        case .error: return "error"
        }
    }

    var outcome: String {
        switch self {
        case .unavailable: return "unavailable"
        case .timeout: return "timeout"
        case .rejected: return "invalid"
        case .error: return "error"
        }
    }
}

nonisolated struct PlannerModelFailure: Error {
    let reason: ModelFallbackReason
    let milliseconds: Int
}

/// All model entry points use this live probe, never a construction-time snapshot.
/// Tests inject a mutable probe and a short deadline without requiring model assets.
@MainActor
final class PlannerModelAccess {
    private let availability: @MainActor @Sendable () -> PlannerModelAvailability
    private let timeout: Duration

    init(availability: (@MainActor @Sendable () -> PlannerModelAvailability)? = nil,
         timeout: Duration? = nil) {
        self.availability = availability ?? { PlannerModelAccess.systemAvailability() }
        self.timeout = timeout ?? .seconds(10)
    }

    static func systemAvailability() -> PlannerModelAvailability {
        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available: return .available
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible: return .unavailable(.deviceNotEligible)
            case .appleIntelligenceNotEnabled: return .unavailable(.appleIntelligenceNotEnabled)
            case .modelNotReady: return .unavailable(.modelNotReady)
            @unknown default: return .unavailable(.other)
            }
        @unknown default: return .unavailable(.other)
        }
        #else
        return .unavailable(.other)
        #endif
    }

    static func reason(for error: Error) -> ModelFallbackReason {
        if let failure = error as? PlannerModelFailure { return failure.reason }
        if error is PlannerCallTimeout { return .timeout }
        if let error = error as? CoachModelError {
            switch error {
            case .unavailable: return .unavailable(.other)
            case .invalid: return .rejected
            }
        }
        #if canImport(FoundationModels)
        if let error = error as? LanguageModelSession.GenerationError {
            switch error {
            case .guardrailViolation, .refusal, .decodingFailure: return .rejected
            case .assetsUnavailable: return .unavailable(.other)
            default: return .error
            }
        }
        #endif
        return .error
    }

    /// A best-effort warm-up at screen entry. No request, profile, history or tools are supplied.
    /// Its result never determines whether a later generation is attempted.
    func prewarm() {
        if case .unavailable(let reason) = availability() {
            PlannerDiagnostics.modelCall("prewarm", outcome: "unavailable", milliseconds: 0,
                                         reason: .unavailable(reason))
            return
        }
        #if canImport(FoundationModels)
        let session = LanguageModelSession()
        session.prewarm()
        PlannerDiagnostics.modelCall("prewarm", outcome: "ok", milliseconds: 0)
        #endif
    }

    func run<Value: Sendable>(_ kind: String, candidates: [GuideCandidate]? = nil,
        operation: @escaping @MainActor @Sendable () async throws -> Value) async throws -> BrainAnswer<Value> {
        let clock = ContinuousClock()
        let start = clock.now
        do {
            try Task.checkCancellation()
            // Read immediately before scheduling each generation, including prefetched rewrites.
            if case .unavailable(let reason) = availability() {
                throw PlannerModelFailure(reason: .unavailable(reason), milliseconds: 0)
            }
            let value = try await PlannerCallDeadline.run(timeout: timeout, operation: operation)
            let ms = PlannerDiagnostics.milliseconds(start.duration(to: clock.now))
            PlannerDiagnostics.modelCall(kind, outcome: "ok", milliseconds: ms, candidates: candidates)
            return BrainAnswer(value: value, source: .onDeviceModel, latencyMilliseconds: ms)
        } catch {
            let reason = Self.reason(for: error)
            let ms = PlannerDiagnostics.milliseconds(start.duration(to: clock.now))
            PlannerDiagnostics.modelCall(kind, outcome: reason.outcome, milliseconds: ms,
                                         reason: reason, error: error, candidates: candidates)
            throw PlannerModelFailure(reason: reason, milliseconds: ms)
        }
    }
}
