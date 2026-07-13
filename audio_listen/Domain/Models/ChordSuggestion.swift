struct SuggestionContext: Hashable {
    let key: Key
    let tierLevel: Int
    let pendingTonic: Int?
}

struct ChordSuggestion: Hashable {
    let chord: ChordSymbol
    let ruleId: SuggestionRuleId
    let keyShiftTonicize: Int?
}
