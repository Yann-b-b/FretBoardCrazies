enum SuggestionRuleId: String, CaseIterable {
    case resolveDominant
    case iiToV
    case diatonicMotion
    case tonicColor
    case dominantUpgrade
    case secondaryDominant
    case tritoneSub
    case modeMixtureIiHalfDim
    case modeMixtureIv
    case dominantAlter
    case minorLineCliche
    case dimPassing
    case dimResolve
    case susDelay
    case extendedColor
}

struct Tier: Hashable {
    let level: Int
    let qualityIds: Set<String>
    let ruleIds: Set<SuggestionRuleId>
}

enum Tiers {
    static let all: [Tier] = [
        Tier(
            level: 1,
            qualityIds: ["maj7", "m7", "7", "m7b5", "6", "m6", "6/9"],
            ruleIds: [.resolveDominant, .iiToV, .diatonicMotion, .tonicColor]
        ),
        Tier(
            level: 2,
            qualityIds: ["9", "13", "maj9"],
            ruleIds: [.dominantUpgrade, .secondaryDominant]
        ),
        Tier(
            level: 3,
            qualityIds: ["7b9", "7#9", "7#5", "7alt", "m(maj7)"],
            ruleIds: [.tritoneSub, .modeMixtureIiHalfDim, .modeMixtureIv, .dominantAlter, .minorLineCliche]
        ),
        Tier(
            level: 4,
            qualityIds: ["maj7#11", "m9", "m11", "m13", "m6/9", "dim7", "7sus4", "9sus4"],
            ruleIds: [.dimPassing, .dimResolve, .susDelay, .extendedColor]
        ),
    ]

    static func unlocked(atLevel level: Int) -> Tier {
        let tiersInReach = all.filter { $0.level <= level }
        return Tier(
            level: level,
            qualityIds: tiersInReach.reduce(into: Set<String>()) { $0.formUnion($1.qualityIds) },
            ruleIds: tiersInReach.reduce(into: Set<SuggestionRuleId>()) { $0.formUnion($1.ruleIds) }
        )
    }

    static func isUnlocked(qualityId: String, ruleId: SuggestionRuleId, level: Int) -> Bool {
        let tier = unlocked(atLevel: level)
        return tier.qualityIds.contains(qualityId) && tier.ruleIds.contains(ruleId)
    }
}
