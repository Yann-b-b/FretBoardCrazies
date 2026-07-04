struct GuitarString: Equatable {
    let openNote: Note
    let startFret: Int
}

struct Instrument: Equatable {
    let id: String
    let name: String
    let strings: [GuitarString]
    let fretCount: Int

    var stringCount: Int { strings.count }

    func note(at string: Int, fret: Int) -> Note? {
        guard string >= 1, string <= strings.count else { return nil }
        let guitarString = strings[string - 1]
        guard fret >= guitarString.startFret, fret <= fretCount else { return nil }
        return Note.from(midiNumber: guitarString.openNote.midiNumber + (fret - guitarString.startFret))
    }

    func positions(for note: Note, maxFretInclusive: Int) -> [FretPosition] {
        let targetMidi = note.midiNumber
        let cap = min(maxFretInclusive, fretCount)
        var result: [FretPosition] = []
        for index in strings.indices {
            let guitarString = strings[index]
            let fret = (targetMidi - guitarString.openNote.midiNumber) + guitarString.startFret
            if fret >= guitarString.startFret, fret <= cap {
                result.append(FretPosition(string: index + 1, fret: fret))
            }
        }
        return result
    }
}
