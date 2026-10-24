// Adapted from a prior prototype, used with permission.

import XCTest
@testable import NearMe

@MainActor
final class KeywordFallbackBrainTests: XCTestCase {
    func testTripSentences() async throws {
        for (sentence, origin, destination) in tripParsingCases {
            let answer = try await KeywordFallbackBrain().extractIntent(from: sentence)
            XCTAssertEqual(answer.value.kind, .planJourney, sentence)
            XCTAssertEqual(normalizedPlace(answer.value.origin), normalizedPlace(origin), sentence)
            XCTAssertEqual(normalizedPlace(answer.value.destination), normalizedPlace(destination), sentence)
            XCTAssertEqual(answer.source, .keywordFallback)
        }
    }

    func testFollowUpPlaces() async throws {
        let cases: [(String, String?)] = [
            ("I'm leaving from Central", "Central"),
            ("um, Town Hall please", "Town Hall"),
            ("Holsworthy.", "Holsworthy"),
            ("um", nil),
            ("I'm at Town Hall, thanks!", "Town Hall"),
            ("uh, er, from Central please, thanks.", "Central"),
            ("to Holsworthy", "Holsworthy"),
            ("it's Central", "Central"),
            ("from", nil),
            ("please", nil),
            ("", nil)
        ]
        for slot in [MissingSlot.origin, .destination] {
            for (sentence, expected) in cases {
                let answer = try await KeywordFallbackBrain().extractPlace(from: sentence, for: slot)
                XCTAssertEqual(normalizedPlace(answer.value), normalizedPlace(expected), sentence)
                XCTAssertEqual(answer.source, .keywordFallback)
            }
        }
    }

    func testConversationAnswersHaveKeywordSource() async throws {
        let brain = KeywordFallbackBrain()
        let question = try await brain.clarifyingQuestion(for: .origin, currentIntent: .empty)
        let confirmation = try await brain.confirmationLine(for: .empty)
        XCTAssertEqual(question.source, .keywordFallback)
        XCTAssertEqual(confirmation.source, .keywordFallback)
    }
}

let tripParsingCases: [(String, String?, String?)] = [
    ("I wanna go from Central to Holsworthy", "Central", "Holsworthy"),
    ("to Parramatta from Town Hall", "Town Hall", "Parramatta"),
    ("I need to get to Town Hall", nil, "Town Hall"),
    ("from Central to Holsworthy, please!", "Central", "Holsworthy"),
    ("to Parramatta from Town Hall, thanks.", "Town Hall", "Parramatta"),
    ("take me to Town Hall please", nil, "Town Hall"),
    ("get me to Holsworthy, thanks!", nil, "Holsworthy")
]

func normalizedPlace(_ place: String?) -> String? {
    place?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
}
