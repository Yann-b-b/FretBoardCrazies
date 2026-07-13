enum SuggestionRanker {
    static func rank(_ candidates: [ChordSuggestion], current: ChordSymbol, key: Key) -> [ChordSuggestion] {
        let deduped = dedup(candidates, current: current, key: key)
        let capped = capSecondaryDominants(deduped, key: key)
        let sorted = capped.sorted { isOrderedBefore($0, $1, current: current, key: key) }
        return Array(sorted.prefix(5))
    }

    private static func mod12(_ x: Int) -> Int {
        ((x % 12) + 12) % 12
    }

    private static func band(_ candidate: ChordSuggestion, current: ChordSymbol, key: Key) -> Int {
        switch candidate.ruleId {
        case .resolveDominant, .dimResolve:
            let landsHomeDiatonic = DiatonicModel.isTonicHere(candidate.chord) || DiatonicModel.isDiatonic(candidate.chord, key)
            return landsHomeDiatonic ? 1 : 7
        case .iiToV:
            return 2
        case .diatonicMotion:
            return candidate.chord.degree == mod12(current.degree + 5) ? 3 : 5
        case .secondaryDominant:
            return 4
        case .tonicColor, .dominantUpgrade, .dominantAlter, .extendedColor, .minorLineCliche:
            return 6
        case .tritoneSub, .dimPassing, .susDelay, .modeMixtureIv, .modeMixtureIiHalfDim:
            return 7
        }
    }

    private static func dedup(_ candidates: [ChordSuggestion], current: ChordSymbol, key: Key) -> [ChordSuggestion] {
        var bestByChord: [ChordSymbol: ChordSuggestion] = [:]
        var order: [ChordSymbol] = []
        for candidate in candidates {
            if let existing = bestByChord[candidate.chord] {
                if band(candidate, current: current, key: key) < band(existing, current: current, key: key) {
                    bestByChord[candidate.chord] = candidate
                }
            } else {
                bestByChord[candidate.chord] = candidate
                order.append(candidate.chord)
            }
        }
        return order.map { bestByChord[$0]! }
    }

    private static func secondaryDominantCentrality(_ target: Int, key: Key) -> Int {
        if target == 7 { return 0 }
        if target == (key.mode == .major ? 2 : 5) { return 1 }
        return 2
    }

    private static func capSecondaryDominants(_ candidates: [ChordSuggestion], key: Key) -> [ChordSuggestion] {
        var secondaryDominants: [ChordSuggestion] = []
        var others: [ChordSuggestion] = []
        for candidate in candidates {
            if candidate.ruleId == .secondaryDominant {
                secondaryDominants.append(candidate)
            } else {
                others.append(candidate)
            }
        }
        let ranked = secondaryDominants.sorted { lhs, rhs in
            let lhsTarget = lhs.keyShiftTonicize ?? Int.max
            let rhsTarget = rhs.keyShiftTonicize ?? Int.max
            let lhsRank = secondaryDominantCentrality(lhsTarget, key: key)
            let rhsRank = secondaryDominantCentrality(rhsTarget, key: key)
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            return lhsTarget < rhsTarget
        }
        return others + Array(ranked.prefix(2))
    }

    private static func tonicRank(_ candidate: ChordSuggestion, key: Key) -> Int {
        if DiatonicModel.isTonicHere(candidate.chord) { return 0 }
        if DiatonicModel.isDiatonic(candidate.chord, key) { return 1 }
        return 2
    }

    private static func dominantMotionRank(_ candidate: ChordSuggestion, current: ChordSymbol) -> Int {
        guard candidate.ruleId == .resolveDominant else { return 0 }
        if candidate.chord.degree == mod12(current.degree + 5) { return 0 }
        if candidate.chord.degree == mod12(current.degree + 11) { return 1 }
        return 2
    }

    private static func rootMotionDistance(_ candidate: ChordSuggestion, current: ChordSymbol) -> Int {
        let diff = mod12(candidate.chord.degree - current.degree)
        return min(diff, 12 - diff)
    }

    private static let majorTonicStability: [String: Int] = [
        "6/9": 0,
        "maj7#11": 0,
        "maj9": 1,
        "maj7": 2,
    ]

    private static let minorTonicStability: [String: Int] = [
        "m6": 0,
        "m(maj7)": 0,
        "m6/9": 1,
        "m9": 2,
    ]

    private static func stabilityRank(_ candidate: ChordSuggestion, key: Key) -> Int {
        guard DiatonicModel.isTonicHere(candidate.chord) else { return 3 }
        let table = key.mode == .major ? majorTonicStability : minorTonicStability
        return table[candidate.chord.qualityId] ?? 3
    }

    private static func isOrderedBefore(_ lhs: ChordSuggestion, _ rhs: ChordSuggestion, current: ChordSymbol, key: Key) -> Bool {
        let lhsBand = band(lhs, current: current, key: key)
        let rhsBand = band(rhs, current: current, key: key)
        if lhsBand != rhsBand { return lhsBand < rhsBand }

        let lhsTonic = tonicRank(lhs, key: key)
        let rhsTonic = tonicRank(rhs, key: key)
        if lhsTonic != rhsTonic { return lhsTonic < rhsTonic }

        let lhsDomMotion = dominantMotionRank(lhs, current: current)
        let rhsDomMotion = dominantMotionRank(rhs, current: current)
        if lhsDomMotion != rhsDomMotion { return lhsDomMotion < rhsDomMotion }

        if lhsBand == 6 {
            let lhsStability = stabilityRank(lhs, key: key)
            let rhsStability = stabilityRank(rhs, key: key)
            if lhsStability != rhsStability { return lhsStability < rhsStability }
        }

        let lhsMotion = rootMotionDistance(lhs, current: current)
        let rhsMotion = rootMotionDistance(rhs, current: current)
        if lhsMotion != rhsMotion { return lhsMotion < rhsMotion }

        if lhs.chord.degree != rhs.chord.degree { return lhs.chord.degree < rhs.chord.degree }
        return lhs.chord.qualityId < rhs.chord.qualityId
    }
}
