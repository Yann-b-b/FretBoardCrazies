import Foundation

@MainActor
final class ChordSuggesterSession: ObservableObject {
    static let minTier = 1
    static let maxTier = 4

    @Published var tonic: NoteName
    @Published var tierLevel: Int
    @Published var revealed: Bool
    @Published private(set) var current: ChordSymbol
    @Published private(set) var lastRuleId: SuggestionRuleId?
    @Published private(set) var step: Int = 0

    private static let recentMemory = 4

    private var pendingTonic: Int?
    private var recent: [ChordSymbol] = []

    init(tonic: NoteName = .c, tierLevel: Int = 1, revealed: Bool = true) {
        self.tonic = tonic
        self.tierLevel = tierLevel
        self.revealed = revealed
        self.current = Self.tonicChord
    }

    private static let tonicChord = ChordSymbol(degree: 0, qualityId: "maj7")

    private var context: SuggestionContext {
        SuggestionContext(key: Key(tonic: tonic, mode: .major), tierLevel: tierLevel, pendingTonic: pendingTonic)
    }

    private func nextSuggestion() -> ChordSuggestion? {
        let ranked = SuggestionEngine.suggest(current: current, context: context)
        guard !ranked.isEmpty else { return nil }
        return ranked.first { !recent.contains($0.chord) } ?? ranked[0]
    }

    var upcoming: ChordSymbol? {
        nextSuggestion()?.chord
    }

    // Same-function richer voicings, so the higher tiers actually practice the
    // extended shapes. The engine always steps on the base functional chord
    // (below); enrichment only changes how that chord is voiced and named. The
    // base is index 0, so a plain voicing recurs while the rest rotate in.
    private static let enrichments: [String: [String]] = [
        "maj7": ["maj7", "maj9", "6/9", "maj7#11"],
        "m7": ["m7", "m9", "m11", "m13"],
        "7": ["7", "9", "13", "7b9", "7#9", "7#5", "7alt"],
    ]

    private func enriched(_ base: ChordSymbol, at rotation: Int) -> ChordSymbol {
        guard let variants = Self.enrichments[base.qualityId] else { return base }
        let unlocked = Tiers.unlocked(atLevel: tierLevel).qualityIds
        let available = variants.filter { unlocked.contains($0) }
        guard !available.isEmpty else { return base }
        return ChordSymbol(degree: base.degree, qualityId: available[rotation % available.count])
    }

    var display: ChordSymbol {
        enriched(current, at: step)
    }

    var displayUpcoming: ChordSymbol? {
        upcoming.map { enriched($0, at: step + 1) }
    }

    func advance() {
        guard let next = nextSuggestion() else {
            resetToTonic()
            return
        }
        pendingTonic = SuggestionEngine.applyKeyShift(context: context, played: next.chord).pendingTonic
        lastRuleId = next.ruleId
        current = next.chord
        recent.append(next.chord)
        if recent.count > Self.recentMemory { recent.removeFirst() }
        step += 1
    }

    func resetToTonic() {
        recent.removeAll()
        pendingTonic = nil
        lastRuleId = nil
        current = Self.tonicChord
        step += 1
    }
}
