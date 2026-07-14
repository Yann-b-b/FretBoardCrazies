import Testing
@testable import audio_listen

struct ChordFormulaConformanceTests {
    private func pitchClasses(of formula: [Int]) -> Set<Int> {
        Set(formula.map { (($0 % 12) + 12) % 12 })
    }

    // The tones that prove a voicing IS its quality: the third (or the sus
    // fourth when there is no third) and the seventh/sixth-family tone.
    // Real voicings drop fifths, ninths, and other tensions, so those are
    // not required — only the guide tones must be present.
    private func guideTones(of formula: Set<Int>) -> Set<Int> {
        let thirdOrSus = [4, 3, 5].first { formula.contains($0) }
        let seventhOrSixth = [10, 11, 9].first { formula.contains($0) }
        return Set([thirdOrSus, seventhOrSixth].compactMap { $0 })
    }

    @Test func everyVoicingSpellsItsQualityAtSeveralRoots() {
        let guitar = Instruments.guitar
        for voicing in Voicings.all {
            let formula = pitchClasses(of: ChordQualities.byId(voicing.qualityId)!.formula)
            let guides = guideTones(of: formula)
            // Roots high enough on the low E (fret >= 3) that the movable
            // shapes with negative offsets (6/9 reaches -3) stay on the neck.
            for rootPitchClass in [7, 9, 0, 2, 4] { // G(3), A(5), C(8), D(10), E(12)
                let placed = ChordPlacement.place(voicing: voicing, rootPitchClass: rootPitchClass, instrument: guitar)
                let intervals = Set(placed.notes.map { note -> Int in
                    let pitchClass = guitar.note(at: note.string, fret: note.fret)!.name.semitonesFromC
                    return (((pitchClass - rootPitchClass) % 12) + 12) % 12
                })
                #expect(intervals.isSubset(of: formula), "\(voicing.qualityId) at root \(rootPitchClass): non-chord tone \(intervals.subtracting(formula).sorted())")
                #expect(guides.isSubset(of: intervals), "\(voicing.qualityId) at root \(rootPitchClass): missing guide tone \(guides.subtracting(intervals).sorted())")
            }
        }
    }
}
