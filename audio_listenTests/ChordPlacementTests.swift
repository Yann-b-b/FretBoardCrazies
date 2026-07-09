import Testing
@testable import audio_listen

struct ChordPlacementTests {
    // Low E open = E (pitch class 4). D = pitch class 2 → fret 10 on the low E string.
    @Test func rootFretForDOnLowEIsTen() {
        let fret = ChordPlacement.rootFret(rootPitchClass: 2, onString: 6, instrument: Instruments.guitar)
        #expect(fret == 10)
    }

    // E itself would be fret 0; movable shapes map it up to fret 12.
    @Test func openNotePitchClassMapsToTwelveNotZero() {
        let fret = ChordPlacement.rootFret(rootPitchClass: 4, onString: 6, instrument: Instruments.guitar)
        #expect(fret == 12)
    }

    @Test func placeAddsRootFretToEveryOffsetAndKeepsStrings() {
        let m7 = Voicings.voicing(qualityId: "m7", rootString: .e6)!
        let placed = ChordPlacement.place(voicing: m7, rootPitchClass: 7, instrument: Instruments.guitar) // G = 7 → fret 3
        #expect(placed.rootFret == 3)
        #expect(placed.rootPosition == FretPosition(string: 6, fret: 3))
        #expect(Set(placed.positions) == Set([
            FretPosition(string: 6, fret: 3),
            FretPosition(string: 4, fret: 3),
            FretPosition(string: 3, fret: 3),
            FretPosition(string: 2, fret: 3),
        ]))
    }
}
