import Testing
@testable import audio_listen

struct ChordSpellingTests {
    @Test func diatonicDegreeUsesKeySignatureLetter() {
        let key = Key(tonic: .c, mode: .major)
        #expect(ChordSpelling.spell(degree: 2, key: key, role: .diatonic) == "D")
    }

    @Test func flatTwoSpellsFlat() {
        let key = Key(tonic: .c, mode: .major)
        #expect(ChordSpelling.spell(degree: 1, key: key, role: .flatSubstitution) == "D♭")
    }

    @Test func flatSevenSpellsFlat() {
        let key = Key(tonic: .c, mode: .major)
        #expect(ChordSpelling.spell(degree: 10, key: key, role: .flatSubstitution) == "B♭")
    }

    @Test func secondaryDominantSpellsTowardResolution() {
        let key = Key(tonic: .c, mode: .major)
        #expect(ChordSpelling.spell(degree: 9, key: key, role: .secondaryDominant) == "A")
    }

    @Test func ascendingPassingSpellsSharp() {
        let key = Key(tonic: .c, mode: .major)
        #expect(ChordSpelling.spell(degree: 1, key: key, role: .ascendingPassing) == "C♯")
    }

    @Test func aMajorDiatonicSeventhDegreeSpellsSharp() {
        let key = Key(tonic: .a, mode: .major)
        #expect(ChordSpelling.spell(degree: 11, key: key, role: .diatonic) == "G♯")
    }

    @Test func aMajorDiatonicChordsUseEachLetterOnce() {
        let key = Key(tonic: .a, mode: .major)
        let degrees = [0, 2, 4, 5, 7, 9, 11]
        let spellings = degrees.map { ChordSpelling.spell(degree: $0, key: key, role: .diatonic) }
        let letters = Set(spellings.map { $0.first! })
        #expect(letters.count == 7)
        #expect(spellings == ["A", "B", "C♯", "D", "E", "F♯", "G♯"])
    }

    @Test func flatThreeAndFlatSixSpellFlat() {
        let key = Key(tonic: .c, mode: .major)
        #expect(ChordSpelling.spell(degree: 3, key: key, role: .flatSubstitution) == "E♭")
        #expect(ChordSpelling.spell(degree: 8, key: key, role: .flatSubstitution) == "A♭")
    }
}
