import Foundation
import Testing
@testable import audio_listen

struct SelectNextPromptTests {
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func candidatesCoverEachAllowedNoteNameOncePerString() {
        let uc = SelectNextPromptUseCase()
        let cands = uc.candidates(
            allowedStrings: Set([6, 5]),
            allowedNoteNames: Set(NoteName.allCases),
            maxFretInclusive: 11
        )
        #expect(cands.count == 24)
        #expect(Set(cands).count == 24)
        #expect(cands.allSatisfy { [6, 5].contains($0.string) })
    }

    @Test func candidatesRespectAllowedNoteNames() {
        let uc = SelectNextPromptUseCase()
        let allowed: Set<NoteName> = [.c, .g]
        let cands = uc.candidates(allowedStrings: Set([6]), allowedNoteNames: allowed, maxFretInclusive: 11)
        #expect(cands.allSatisfy { allowed.contains($0.noteName) })
        #expect(cands.count == 2)
    }

    @Test func nextReturnsNilWhenNoCandidates() {
        let uc = SelectNextPromptUseCase()
        let prompt = uc.next(allowedStrings: [], allowedNoteNames: Set(NoteName.allCases), maxFretInclusive: 11, stats: [:], now: now, randomUnit: { 0.0 })
        #expect(prompt == nil)
    }

    @Test func nextProducesAValidPromptForTheCandidate() {
        let uc = SelectNextPromptUseCase()
        let prompt = uc.next(allowedStrings: Set([6]), allowedNoteNames: [.e], maxFretInclusive: 11, stats: [:], now: now, randomUnit: { 0.99 })
        #expect(prompt != nil)
        #expect(prompt?.string == 6)
        #expect(prompt?.targetNote.name == .e)
        let board = GuitarFretboard.note(at: prompt!.string, fret: 0)
        #expect(board?.name == .e)
    }

    @Test func weightingPrefersLowerBoxItems() {
        let uc = SelectNextPromptUseCase(maxBox: 4, nameNoteProbability: 0.0)
        let weakKey = DrillItemKey(noteName: .c, string: 6)
        let strongKey = DrillItemKey(noteName: .f, string: 6)
        let stats: [DrillItemKey: ItemStats] = [
            weakKey: ItemStats(box: 0, attempts: 1, correct: 0, lastReactionTime: nil, lastSeenAt: now),
            strongKey: ItemStats(box: 4, attempts: 9, correct: 9, lastReactionTime: 1.0, lastSeenAt: now)
        ]
        let prompt = uc.next(allowedStrings: Set([6]), allowedNoteNames: [.c, .f], maxFretInclusive: 11, stats: stats, now: now, randomUnit: { 0.0 })
        #expect(prompt?.itemKey == weakKey)
    }

    @Test func directionUsesNameNoteWhenRandomBelowProbability() {
        let uc = SelectNextPromptUseCase(maxBox: 4, nameNoteProbability: 0.5)
        var calls = 0
        let randoms: [Double] = [0.1, 0.0]
        let prompt = uc.next(allowedStrings: Set([6]), allowedNoteNames: [.e], maxFretInclusive: 11, stats: [:], now: now, randomUnit: {
            defer { calls += 1 }
            return randoms[min(calls, randoms.count - 1)]
        })
        #expect(prompt?.direction == .nameNote)
    }
}
