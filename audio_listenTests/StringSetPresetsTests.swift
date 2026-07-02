import Testing
@testable import audio_listen

struct StringSetPresetsTests {
    @Test func presetsAreCumulativeFromLowE() {
        let all = StringSetPresets.all
        #expect(all.count == 5)
        #expect(all[0].strings == Set([6, 5]))
        #expect(all[1].strings == Set([6, 5, 4]))
        #expect(all[2].strings == Set([6, 5, 4, 3]))
        #expect(all[3].strings == Set([6, 5, 4, 3, 2]))
        #expect(all[4].strings == Set(1...6))
    }

    @Test func presetIdsAreUnique() {
        let ids = StringSetPresets.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func singlesMapToOneStringEach() {
        #expect(StringSetPresets.singles.map(\.strings) == [[6], [5], [4], [3], [2], [1]])
    }

    @Test func choiceIdsAreUniqueAcrossPresetsAndSingles() {
        let ids = StringSetPresets.choices.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func defaultChoiceIsEAndA() {
        #expect(StringSetPresets.defaultStrings == Set([6, 5]))
        #expect(StringSetPresets.defaultChoice.strings == Set([6, 5]))
    }
}
