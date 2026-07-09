enum Progressions {
    private static func step(_ degree: Int, _ qualityId: String) -> ProgressionStep {
        ProgressionStep(degree: degree, qualityId: qualityId)
    }

    static let all: [Progression] = [
        Progression(id: "major-ii-v-i", name: "Major ii–V–I", steps: [
            step(2, "m7"), step(7, "7"), step(0, "maj7"),
        ]),
        Progression(id: "turnaround", name: "I–VI–ii–V turnaround", steps: [
            step(0, "maj7"), step(9, "7"), step(2, "m7"), step(7, "7"),
        ]),
        Progression(id: "minor-ii-v-i", name: "Minor ii–V–i", steps: [
            step(2, "m7b5"), step(7, "7"), step(0, "m7"),
        ]),
        Progression(id: "sixth-loop", name: "6th-chord loop", steps: [
            step(0, "6"), step(9, "m7"), step(2, "m7"), step(7, "7"),
        ]),
        Progression(id: "dominant-blues", name: "Dominant blues", steps: [
            step(0, "7"), step(5, "7"), step(0, "7"), step(0, "7"),
            step(5, "7"), step(5, "7"), step(0, "7"), step(0, "7"),
            step(7, "7"), step(5, "7"), step(0, "7"), step(7, "7"),
        ]),
        Progression(id: "minor-six-tonic", name: "Minor-6 tonic", steps: [
            step(0, "m6"), step(5, "m7"), step(7, "7"), step(0, "m6"),
        ]),
    ]

    static func byId(_ id: String) -> Progression? {
        all.first { $0.id == id }
    }
}
