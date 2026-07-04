import Testing
@testable import audio_listen

struct InstrumentTests {
    let guitar = Instruments.guitar

    @Test func openLowEIsE2() {
        #expect(guitar.note(at: 6, fret: 0) == Note(.e, octave: 2))
    }

    @Test func openHighEIsE4() {
        #expect(guitar.note(at: 1, fret: 0) == Note(.e, octave: 4))
    }

    @Test func openAStringIsA2() {
        #expect(guitar.note(at: 5, fret: 0) == Note(.a, octave: 2))
    }

    @Test func stringCountIsSix() {
        #expect(guitar.stringCount == 6)
    }

    @Test func positionsRoundTrip() {
        let target = Note(.g, octave: 3)
        let positions = guitar.positions(for: target, maxFretInclusive: 24)
        #expect(!positions.isEmpty)
        for pos in positions {
            #expect(guitar.note(at: pos.string, fret: pos.fret) == target)
        }
    }

    @Test func positionsRespectMaxFret() {
        let target = Note(.e, octave: 3)
        let at12 = guitar.positions(for: target, maxFretInclusive: 12)
        let at11 = guitar.positions(for: target, maxFretInclusive: 11)
        #expect(at12.contains { $0.fret == 12 })
        #expect(!at11.contains { $0.fret == 12 })
    }

    @Test func outOfRangeYieldsNil() {
        #expect(guitar.note(at: 6, fret: 25) == nil)
        #expect(guitar.note(at: 0, fret: 0) == nil)
        #expect(guitar.note(at: 7, fret: 0) == nil)
    }

    @Test func droneStringStartsAtItsStartFret() {
        let drone = GuitarString(openNote: Note(.g, octave: 4), startFret: 5)
        let banjoish = Instrument(id: "test", name: "Test", strings: [drone], fretCount: 22)
        #expect(banjoish.note(at: 1, fret: 3) == nil)
        #expect(banjoish.note(at: 1, fret: 5) == Note(.g, octave: 4))
        #expect(banjoish.note(at: 1, fret: 6) == Note(.gSharp, octave: 4))
    }

    @Test func dronePositionsOffsetByStartFret() {
        let drone = GuitarString(openNote: Note(.g, octave: 4), startFret: 5)
        let banjoish = Instrument(id: "test", name: "Test", strings: [drone], fretCount: 22)
        #expect(banjoish.positions(for: Note(.g, octave: 4), maxFretInclusive: 22) == [FretPosition(string: 1, fret: 5)])
    }
}
