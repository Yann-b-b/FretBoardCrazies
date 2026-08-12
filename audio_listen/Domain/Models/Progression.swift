struct ProgressionStep: Hashable {
    let degree: Int
    let qualityId: String
}

struct Progression: Hashable {
    let id: String
    let name: String
    let steps: [ProgressionStep]
}
