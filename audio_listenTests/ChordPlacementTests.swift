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

    @Test func placeThreadsRootFretFingersAndRootFlag() {
        let m7 = Voicings.voicing(qualityId: "m7", rootString: .e6)!
        let placed = ChordPlacement.place(voicing: m7, rootPitchClass: 7, instrument: Instruments.guitar) // G = 7 → fret 3
        #expect(placed.rootFret == 3)
        // one note per voicing position, string+fret preserved
        #expect(Set(placed.notes.map { $0.string }) == Set([6, 4, 3, 2]))
        #expect(placed.notes.allSatisfy { $0.fret == 3 })
        // exactly the low-E (string 6) note is the root
        let roots = placed.notes.filter { $0.isRoot }
        #expect(roots.count == 1)
        #expect(roots.first?.string == 6)
        // fingers come from the voicing (m7 is an all-index barre → all finger 1)
        #expect(placed.notes.allSatisfy { $0.finger == 1 })
    }

    // Voicings with negative offsets (6/9 reaches -3) must never draw past the
    // nut: place raises the root an octave until the whole shape fits.
    @Test func noVoicingPlacesANegativeFretAtAnyTonic() {
        for voicing in Voicings.all {
            for rootPitchClass in 0..<12 {
                let placed = ChordPlacement.place(voicing: voicing, rootPitchClass: rootPitchClass, instrument: Instruments.guitar)
                #expect(placed.notes.allSatisfy { $0.fret >= 0 }, "\(voicing.qualityId) at root \(rootPitchClass): \(placed.notes.map(\.fret).sorted())")
            }
        }
    }

    // The octave bump preserves pitch classes: F6/9 (root at fret 1) moves to
    // fret 13 so its -3 offset lands on fret 10, not -2.
    @Test func lowRootWithNegativeOffsetBumpsUpAnOctave() {
        let sixNine = Voicings.voicing(qualityId: "6/9", rootString: .e6)!
        let placed = ChordPlacement.place(voicing: sixNine, rootPitchClass: 5, instrument: Instruments.guitar) // F
        #expect(placed.rootFret == 13)
        #expect(placed.notes.allSatisfy { $0.fret >= 0 })
    }
}
