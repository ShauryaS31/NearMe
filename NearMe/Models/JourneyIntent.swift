// Adapted from a prior prototype, used with permission.

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum JourneyIntentKind: String, Codable, CaseIterable, Sendable {
    case planJourney = "plan_journey"
    case unknown
}

enum MissingSlot: String, Sendable, Equatable {
    case origin
    case destination
}

#if canImport(FoundationModels)
@Generable
struct JourneyIntent: Sendable {
    @Guide(description: "What the user is trying to do. Use plan_journey when they want help getting from one place to another via public transport; otherwise unknown.")
    var intent: JourneyIntentKindGenerable

    @Guide(description: "A short destination station or place name of at most 5 words. Nil if not mentioned.")
    var destination: String?

    @Guide(description: "A short origin station or place name of at most 5 words. Nil if not mentioned.")
    var origin: String?

    @Guide(description: "The transport mode if the user specified one, e.g. train, tram, bus. Nil if not mentioned.")
    var mode: String?
}

/// FoundationModels' `@Generable` macro needs an enum that is itself
/// `@Generable`-compatible; we keep the public-facing `JourneyIntentKind`
/// as a plain Swift enum (used throughout the rest of the app) and map
/// between the two at the boundary.
@Generable
enum JourneyIntentKindGenerable: String, Sendable {
    case planJourney = "plan_journey"
    case unknown
}

extension JourneyIntent {
    var kind: JourneyIntentKind {
        JourneyIntentKind(rawValue: intent.rawValue) ?? .unknown
    }
}
#else
/// Plain fallback definition used when building for a platform/OS version
/// where the FoundationModels framework isn't available (e.g. an older
/// simulator runtime). Field-for-field identical to the `@Generable` version
/// above so the rest of the app never needs `#if canImport` checks.
struct JourneyIntent: Sendable {
    var intent: JourneyIntentKind
    var destination: String?
    var origin: String?
    var mode: String?

    var kind: JourneyIntentKind { intent }
}
#endif

extension JourneyIntent {
    static var empty: JourneyIntent {
        #if canImport(FoundationModels)
        JourneyIntent(intent: .unknown, destination: nil, origin: nil, mode: nil)
        #else
        JourneyIntent(intent: .unknown, destination: nil, origin: nil, mode: nil)
        #endif
    }

    /// The first slot (in the order NearMe asks about them) that's still
    /// empty, or `nil` if the intent is fully specified.
    var firstMissingSlot: MissingSlot? {
        if origin == nil || origin?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            return .origin
        }
        if destination == nil || destination?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            return .destination
        }
        return nil
    }

    func filling(_ slot: MissingSlot, with value: String) -> JourneyIntent {
        var copy = self
        switch slot {
        case .origin: copy.origin = value
        case .destination: copy.destination = value
        }
        return copy
    }
}
