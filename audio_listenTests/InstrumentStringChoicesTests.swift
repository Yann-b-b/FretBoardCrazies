import Testing
@testable import audio_listen

struct InstrumentStringChoicesTests {
    private var guitar: Instrument { Instruments.guitar }

    private var bass: Instrument {
        Instrument(
            id: "bass",
            name: "Bass",
            strings: [
                Note(.g, octave: 2), Note(.d, octave: 2),
                Note(.a, octave: 1), Note(.e, octave: 1)
            ].map { GuitarString(openNote: $0, startFret: 0) },
            fretCount: 24
        )
    }

    @Test func guitarHasSixSinglesLowToHigh() {
        #expect(guitar.singleStringChoices.map(\.strings) == [[6], [5], [4], [3], [2], [1]])
    }

    @Test func guitarSingleLabelsDisambiguateDuplicateE() {
        #expect(guitar.singleStringChoices.map(\.label) == ["Low E", "A", "D", "G", "B", "High E"])
    }

    @Test func guitarCumulativeIsFirstTwoThroughSix() {
        #expect(guitar.cumulativeStringChoices.map(\.strings) == [
            [6, 5], [6, 5, 4], [6, 5, 4, 3], [6, 5, 4, 3, 2], [6, 5, 4, 3, 2, 1]
        ])
    }

    @Test func guitarCumulativeLabelsAreNoteNamesLowToHigh() {
        #expect(guitar.cumulativeStringChoices.map(\.label) == [
            "E · A", "E · A · D", "E · A · D · G", "E · A · D · G · B", "E · A · D · G · B · E"
        ])
    }

    @Test func guitarDefaultIsLowestSingleString() {
        #expect(guitar.defaultStringChoice.strings == Set([6]))
    }

    @Test func guitarStringChoicesAreSinglesThenCumulative() {
        let choices = guitar.stringChoices
        #expect(choices.count == 11)
        #expect(choices.prefix(6).map(\.strings) == guitar.singleStringChoices.map(\.strings))
        #expect(choices.suffix(5).map(\.strings) == guitar.cumulativeStringChoices.map(\.strings))
    }

    @Test func choiceIdsAreUnique() {
        let ids = guitar.stringChoices.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func bassHasFourSinglesAndDefaultsToLowest() {
        #expect(bass.singleStringChoices.map(\.strings) == [[4], [3], [2], [1]])
        #expect(bass.defaultStringChoice.strings == Set([4]))
    }

    @Test func bassCumulativeIsFirstTwoThroughFour() {
        #expect(bass.cumulativeStringChoices.map(\.strings) == [[4, 3], [4, 3, 2], [4, 3, 2, 1]])
    }

    @Test func bassSingleLabelsAreUniqueNoteNames() {
        #expect(bass.singleStringChoices.map(\.label) == ["E", "A", "D", "G"])
    }

    @Test func threeSameNamesUseOctaveQualifiedLabels() {
        let triple = Instrument(
            id: "triple-e",
            name: "Triple E",
            strings: [
                Note(.e, octave: 4), Note(.e, octave: 3), Note(.e, octave: 2)
            ].map { GuitarString(openNote: $0, startFret: 0) },
            fretCount: 12
        )
        #expect(triple.singleStringChoices.map(\.label) == ["E2", "E3", "E4"])
    }
}
