struct PlacedNote: Hashable {
    let string: Int
    let fret: Int
    let finger: Int
    let isRoot: Bool
}

struct PlacedChord: Hashable {
    let rootFret: Int
    let notes: [PlacedNote]
}

enum ChordPlacement {
    static func rootFret(rootPitchClass: Int, onString stringNumber: Int, instrument: Instrument) -> Int {
        let open = instrument.note(at: stringNumber, fret: 0)!.name.semitonesFromC
        let base = (((rootPitchClass - open) % 12) + 12) % 12
        return base == 0 ? 12 : base
    }

    static func place(voicing: Voicing, rootPitchClass: Int, instrument: Instrument) -> PlacedChord {
        let rootStringNumber = voicing.rootString.stringNumber
        var fret = rootFret(rootPitchClass: rootPitchClass, onString: rootStringNumber, instrument: instrument)
        let lowestOffset = voicing.positions.map(\.fretOffset).min() ?? 0
        while fret + lowestOffset < 0 { fret += 12 }
        let notes = voicing.positions.map { position in
            PlacedNote(
                string: position.string,
                fret: fret + position.fretOffset,
                finger: position.finger,
                isRoot: position.string == rootStringNumber && position.fretOffset == 0
            )
        }
        return PlacedChord(rootFret: fret, notes: notes)
    }
}
