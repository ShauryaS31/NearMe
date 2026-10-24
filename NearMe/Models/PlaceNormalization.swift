import Foundation

nonisolated enum PlaceNormalization {
    /// Model placeholders are missing values, never destinations or origins.
    static func normalize(_ value: String?) -> String? {
        guard let place = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !["", "nil", "null", "none", "unknown", "n/a", "-"].contains(place.lowercased()) else {
            return nil
        }
        return place
    }
}
