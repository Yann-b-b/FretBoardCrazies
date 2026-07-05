enum Instruments {
    static let guitar = Instrument(
        id: "guitar",
        name: "Guitar",
        strings: [
            Note(.e, octave: 4), Note(.b, octave: 3), Note(.g, octave: 3),
            Note(.d, octave: 3), Note(.a, octave: 2), Note(.e, octave: 2)
        ].map { GuitarString(openNote: $0, startFret: 0) },
        fretCount: 24
    )

    static let bass = Instrument(
        id: "bass",
        name: "Bass",
        strings: [
            Note(.g, octave: 2), Note(.d, octave: 2), Note(.a, octave: 1), Note(.e, octave: 1)
        ].map { GuitarString(openNote: $0, startFret: 0) },
        fretCount: 21
    )

    static let all: [Instrument] = [guitar, bass]
}
