import Testing
@testable import audio_listen

struct ChordFormulaConformanceTests {
    @Test func everyVoicingSpellsItsQualityAtSeveralRoots() {
        let guitar = Instruments.guitar
        for voicing in Voicings.all {
            let formula = Set(ChordQualities.byId(voicing.qualityId)!.formula)
            let required = formula.filter { $0 != 7 } // the perfect 5th may be dropped
            for rootPitchClass in [0, 2, 5, 7, 10] { // C, D, F, G, A#
                let placed = ChordPlacement.place(voicing: voicing, rootPitchClass: rootPitchClass, instrument: guitar)
                let intervals = Set(placed.notes.map { note -> Int in
                    let pitchClass = guitar.note(at: note.string, fret: note.fret)!.name.semitonesFromC
                    return (((pitchClass - rootPitchClass) % 12) + 12) % 12
                })
                #expect(intervals.isSubset(of: formula), "\(voicing.qualityId) at root \(rootPitchClass) has non-chord tone: \(intervals.sorted()) ⊄ \(formula.sorted())")
                #expect(required.isSubset(of: intervals), "\(voicing.qualityId) at root \(rootPitchClass) missing required tone: \(required.sorted()) ⊄ \(intervals.sorted())")
            }
        }
    }
}
