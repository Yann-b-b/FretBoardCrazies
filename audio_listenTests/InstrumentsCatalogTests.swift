import Testing
@testable import audio_listen

struct InstrumentsCatalogTests {
    @Test func catalogIsGuitarThenBass() {
        #expect(Instruments.all.map(\.id) == ["guitar", "bass"])
    }

    @Test func bassIsFourStringStandardTuning() {
        let bass = Instruments.bass
        #expect(bass.stringCount == 4)
        #expect(bass.fretCount == 21)
        #expect(bass.note(at: 4, fret: 0) == Note(.e, octave: 1))
        #expect(bass.note(at: 3, fret: 0) == Note(.a, octave: 1))
        #expect(bass.note(at: 2, fret: 0) == Note(.d, octave: 2))
        #expect(bass.note(at: 1, fret: 0) == Note(.g, octave: 2))
    }

    @Test func bassDefaultStringChoiceIsLowestString() {
        #expect(Instruments.bass.defaultStringChoice.strings == Set([4]))
    }
}
