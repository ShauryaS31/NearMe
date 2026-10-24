import Foundation
import NaturalLanguage
import OSLog

nonisolated enum HelpRoute: Equatable, Sendable {
    case practiceTripPlanner
    case practiceVideo
    case guide(String)
    case general
    var description: String {
        switch self {
        case .practiceTripPlanner: return "practiceTripPlanner"
        case .practiceVideo: return "practiceVideo"
        case .guide(let id): return id
        case .general: return "general"
        }
    }
}

nonisolated struct HelpChoice: Equatable, Sendable {
    let route: HelpRoute
    var person: String? = nil
    var song: String? = nil
}

nonisolated struct GuideCandidate: Sendable {
    let id: String
    let title: String
    let aliases: [String]
    let score: Double
}

nonisolated enum GuidePrefilter {
    static let fallbackThreshold = 0.56

    static func cosine(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        let norm = sqrt(a.reduce(0) { $0 + $1 * $1 } * b.reduce(0) { $0 + $1 * $1 })
        guard norm > 0 else { return 0 }
        return zip(a, b).reduce(0) { $0 + $1.0 * $1.1 } / norm
    }

    static func words(_ text: String) -> Set<String> {
        let synonyms = ["image": "photo", "images": "photo", "picture": "photo", "pictures": "photo",
                        "photos": "photo", "writing": "text", "letters": "text", "larger": "bigger",
                        "small": "bigger", "tiny": "bigger", "bhejna": "send", "bhejni": "send"]
        let ignored = Set("i my me your the a an to on in with of for is it do how can you help want please hai pe ki karna".split(separator: " ").map(String.init))
        return Set(text.lowercased().components(separatedBy: .alphanumerics.inverted)
            .filter { !$0.isEmpty && !ignored.contains($0) }.map { synonyms[$0] ?? $0 })
    }

    static func keywordScore(_ request: String, guide: HelpGuide) -> Double {
        let query = words(request)
        let aliasScore = ([guide.title] + guide.aliases).map { alias -> Double in
            let tokens = words(alias)
            guard !tokens.isEmpty else { return 0 }
            return Double(query.intersection(tokens).count) / Double(max(tokens.count, query.count))
        }.max() ?? 0
        var score = aliasScore
        if guide.id == "youtube_play_song",
           !query.isDisjoint(with: ["youtube", "song", "gaana", "bhajan"]) || query.isSuperset(of: ["music", "video"]) {
            score = 1
        }
        if guide.id == "whatsapp_send_photo", query.contains("photo"), query.contains("send") {
            score = max(score, query.contains("whatsapp") ? 1 : 0.9)
        }
        if guide.id == "whatsapp_video_call", query.isSuperset(of: ["video", "call"]) {
            score = max(score, query.contains("facetime") ? 0.3 : 0.95)
        }
        if guide.id == "iphone_text_bigger", query.contains("text"), query.contains("bigger") {
            score = 1
        }
        return score
    }

    /// Pure ranking: callers provide optional sentence vectors; tests need no model assets.
    static func rank(request: String, guides: [HelpGuide], requestVector: [Double]? = nil,
                     guideVectors: [String: [Double]]? = nil) -> [GuideCandidate] {
        let scored: [GuideCandidate] = guides.map { guide -> GuideCandidate in
            let keyword = keywordScore(request, guide: guide)
            let score: Double
            if let requestVector, let vector = guideVectors?[guide.id] {
                score = 0.8 * keyword + 0.2 * max(0, cosine(requestVector, vector))
            } else { score = keyword }
            return GuideCandidate(id: guide.id, title: guide.title, aliases: guide.aliases, score: score)
        }
        let ranked: [GuideCandidate] = scored.sorted { left, right in
            if left.score == right.score { return left.id < right.id }
            return left.score > right.score
        }
        let top: ArraySlice<GuideCandidate> = ranked.prefix(3)
        return Array(top)
    }

    static func practiceRoute(for request: String) -> HelpRoute? {
        guard CoachText.matches(request, #"(?i)\b(practi[cs](?:e|ing)|practice|rehearse|rehearsal)\b"#) else { return nil }
        if CoachText.matches(request, #"(?i)\b(trip|train|travel|journey|station|tram|bus)\b"#) {
            return .practiceTripPlanner
        }
        if CoachText.matches(request, #"(?i)\b(song|music|video|youtube|playing|first|safely)\b"#) {
            return .practiceVideo
        }
        return nil
    }

    static func fallback(request: String, candidates: [GuideCandidate]) -> HelpChoice {
        let route: HelpRoute
        if let practice = practiceRoute(for: request) { route = practice }
        else if let top = candidates.first, top.score >= fallbackThreshold { route = .guide(top.id) }
        else if CoachText.matches(request, #"(?i)\b(trip|train|travel|journey|station|tram|bus)\b|\bfrom\s+.+\s+to\b|^to\s+|\bget to\b"#) { route = .practiceTripPlanner }
        else { route = .general }
        return HelpChoice(route: route, person: PersonNormalization.extract(from: request),
                          song: route == .guide("youtube_play_song") ? SongNormalization.extract(from: request) : nil)
    }
}

@MainActor
protocol HelpRouting {
    func route(_ request: String) async -> BrainAnswer<HelpChoice>
}

@MainActor
final class HelpRouter: HelpRouting {
    private let guides: [HelpGuide]
    private let service: CoachModelService
    private let embedding: NLEmbedding?
    private var vectors: [String: [Double]] = [:]

    init(guides: [HelpGuide], service: CoachModelService, useEmbeddings: Bool = true) {
        self.guides = guides
        self.service = service
        embedding = useEmbeddings ? NLEmbedding.sentenceEmbedding(for: .english) : nil
        for guide in guides {
            vectors[guide.id] = embedding?.vector(for: ([guide.title] + guide.aliases).joined(separator: ". "))
        }
    }

    func route(_ request: String) async -> BrainAnswer<HelpChoice> {
        let candidates = GuidePrefilter.rank(request: request, guides: guides,
                                            requestVector: embedding?.vector(for: request), guideVectors: vectors)
        let fallback = GuidePrefilter.fallback(request: request, candidates: candidates)
        let strongMatch = candidates.first.flatMap { $0.score >= GuidePrefilter.fallbackThreshold ? $0 : nil }
        let answer = await service.perform("router", fallback: fallback, candidates: candidates) { brain in
            let choice = try await brain.route(request: request, candidates: candidates)
            if let practice = GuidePrefilter.practiceRoute(for: request), choice.route != practice {
                throw CoachModelError.invalid
            }
            if case .guide(let id) = choice.route, !candidates.contains(where: { $0.id == id }), strongMatch == nil {
                throw CoachModelError.invalid
            }
            // An explicit recipient in the request wins over a model placeholder or wrong person.
            return HelpChoice(route: choice.route, person: PersonNormalization.extract(from: request)
                              ?? PersonNormalization.extractedPerson(choice.person),
                              song: SongNormalization.extract(from: request) ?? SongNormalization.normalize(choice.song))
        }
        guard answer.source == .onDeviceModel, let top = strongMatch else { return answer }
        let needsOverride: Bool
        switch answer.value.route {
        case .general: needsOverride = true
        case .guide(let id): needsOverride = !candidates.contains { $0.id == id }
        case .practiceTripPlanner, .practiceVideo: needsOverride = false
        }
        guard needsOverride else { return answer }
        PlannerDiagnostics.logger.notice("On-device model + keyword fill reason=general overridden by guide match topCandidate=\(top.id, privacy: .public) topScore=\(top.score, privacy: .public)")
        return BrainAnswer(value: HelpChoice(route: .guide(top.id), person: answer.value.person, song: answer.value.song),
                           source: .onDeviceModelWithKeywordFill, latencyMilliseconds: answer.latencyMilliseconds)
    }
}
