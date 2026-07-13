enum SuggestionEngine {
    static func suggest(current: ChordSymbol, context: SuggestionContext) -> [ChordSuggestion] {
        let candidates = SuggestionGenerators.all(current: current, key: context.key)
        let unlocked = candidates.filter {
            Tiers.isUnlocked(qualityId: $0.chord.qualityId, ruleId: $0.ruleId, level: context.tierLevel)
        }
        return SuggestionRanker.rank(unlocked, current: current, key: context.key)
    }

    static func applyKeyShift(context: SuggestionContext, played: ChordSymbol) -> SuggestionContext {
        if let target = secondaryDominantTarget(of: played, key: context.key) {
            return SuggestionContext(key: context.key, tierLevel: context.tierLevel, pendingTonic: target)
        }
        if context.pendingTonic != nil, DiatonicModel.isDiatonic(played, context.key) {
            return SuggestionContext(key: context.key, tierLevel: context.tierLevel, pendingTonic: nil)
        }
        return context
    }

    private static func secondaryDominantTarget(of played: ChordSymbol, key: Key) -> Int? {
        guard played.qualityId == "7" else { return nil }
        let target = mod12(played.degree - 7)
        guard DiatonicModel.targets(key).contains(target) else { return nil }
        return target
    }

    private static func mod12(_ x: Int) -> Int {
        ((x % 12) + 12) % 12
    }
}
