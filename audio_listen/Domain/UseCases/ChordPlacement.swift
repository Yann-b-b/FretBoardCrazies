struct PlacedChord: Hashable {
    let rootFret: Int
    let positions: [FretPosition]
    let rootPosition: FretPosition
}

enum ChordPlacement {
    static func rootFret(rootPitchClass: Int, onString stringNumber: Int, instrument: Instrument) -> Int {
        let open = instrument.note(at: stringNumber, fret: 0)!.name.semitonesFromC
        let base = (((rootPitchClass - open) % 12) + 12) % 12
        return base == 0 ? 12 : base
    }

    static func place(voicing: Voicing, rootPitchClass: Int, instrument: Instrument) -> PlacedChord {
        let fret = rootFret(rootPitchClass: rootPitchClass, onString: voicing.rootString.stringNumber, instrument: instrument)
        let positions = voicing.positions.map { FretPosition(string: $0.string, fret: fret + $0.fretOffset) }
        let root = FretPosition(string: voicing.rootString.stringNumber, fret: fret)
        return PlacedChord(rootFret: fret, positions: positions, rootPosition: root)
    }
}
