enum MasteryLevel {
    case unseen
    case learning
    case mastered

    static func from(box: Int, attempts: Int, masteredBox: Int) -> MasteryLevel {
        if attempts == 0 { return .unseen }
        return box >= masteredBox ? .mastered : .learning
    }
}
