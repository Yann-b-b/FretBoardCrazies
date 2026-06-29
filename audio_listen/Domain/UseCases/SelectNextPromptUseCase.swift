import Foundation

struct SelectNextPromptUseCase {
    let maxBox: Int
    let nameNoteProbability: Double

    init(maxBox: Int = DrillTuning.maxBox, nameNoteProbability: Double = 0.25) {
        self.maxBox = maxBox
        self.nameNoteProbability = nameNoteProbability
    }

    func candidates(
        allowedStrings: Set<Int>,
        allowedNoteNames: Set<NoteName>,
        maxFretInclusive: Int
    ) -> [DrillItemKey] {
        var result: [DrillItemKey] = []
        for string in allowedStrings.sorted() {
            for fret in 0...maxFretInclusive {
                guard let note = GuitarFretboard.note(at: string, fret: fret) else { continue }
                guard allowedNoteNames.contains(note.name) else { continue }
                let key = DrillItemKey(noteName: note.name, string: string)
                if !result.contains(key) {
                    result.append(key)
                }
            }
        }
        return result
    }

    func next(
        allowedStrings: Set<Int>,
        allowedNoteNames: Set<NoteName>,
        maxFretInclusive: Int,
        stats: [DrillItemKey: ItemStats],
        now _: Date,
        randomUnit: () -> Double
    ) -> DrillPrompt? {
        let keys = candidates(allowedStrings: allowedStrings, allowedNoteNames: allowedNoteNames, maxFretInclusive: maxFretInclusive)
        guard !keys.isEmpty else { return nil }

        let weights = keys.map { key -> Double in
            let box = stats[key]?.box ?? 0
            return Double(maxBox - box) + 1
        }
        let total = weights.reduce(0, +)
        let directionRoll = randomUnit()
        let pick = randomUnit() * total

        let sortedPairs = zip(keys, weights).sorted { $0.1 > $1.1 }
        var cumulative = 0.0
        var chosen = sortedPairs[0].0
        for (key, weight) in sortedPairs {
            cumulative += weight
            if pick < cumulative {
                chosen = key
                break
            }
        }

        guard let note = noteFor(key: chosen, maxFretInclusive: maxFretInclusive) else { return nil }
        let direction: DrillDirection = directionRoll < nameNoteProbability ? .nameNote : .findPosition
        return DrillPrompt(direction: direction, targetNote: note, string: chosen.string)
    }

    private func noteFor(key: DrillItemKey, maxFretInclusive: Int) -> Note? {
        for fret in 0...maxFretInclusive {
            if let note = GuitarFretboard.note(at: key.string, fret: fret), note.name == key.noteName {
                return note
            }
        }
        return nil
    }
}
