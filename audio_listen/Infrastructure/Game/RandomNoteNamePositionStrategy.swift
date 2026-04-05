//
//  RandomNoteNamePositionStrategy.swift
//  audio_listen
//
//  Strategy: pick a random board position whose note name is in the allowed set (random string among matches).
//

import Foundation

/// Picks a random `(Note, FretPosition)` where `note.name` is one of the allowed pitch classes.
/// Uses all six strings; string choice in the classic game tab does not apply here.
struct RandomNoteNamePositionStrategy: NoteGeneratorProtocol {
    private let allowedNoteNamesProvider: AllowedNoteNamesProviding
    private let maxFretProvider: MaxFretProviding

    init(
        allowedNoteNamesProvider: AllowedNoteNamesProviding,
        maxFretProvider: MaxFretProviding
    ) {
        self.allowedNoteNamesProvider = allowedNoteNamesProvider
        self.maxFretProvider = maxFretProvider
    }

    /// All `(note, position)` on allowed strings and frets whose `note.name` is in `allowedNames`.
    static func matchingTargets(
        allowedNoteNames: Set<NoteName>,
        maxFretInclusive: Int,
        allowedStrings: Set<Int>
    ) -> [(Note, FretPosition)] {
        let cap = min(maxFretInclusive, GuitarFretboard.fretCount)
        var out: [(Note, FretPosition)] = []
        for string in 1...6 where allowedStrings.contains(string) {
            for fret in 0...cap {
                guard let note = GuitarFretboard.note(at: string, fret: fret),
                      allowedNoteNames.contains(note.name) else { continue }
                out.append((note, FretPosition(string: string, fret: fret)))
            }
        }
        return out
    }

    func nextTarget() -> (Note, FretPosition) {
        let allowedStrings = Set(1...6)
        let allowedNames = allowedNoteNamesProvider.allowedNoteNames
        let maxFret = maxFretProvider.maxFretInclusive
        let candidates = Self.matchingTargets(
            allowedNoteNames: allowedNames,
            maxFretInclusive: maxFret,
            allowedStrings: allowedStrings
        )

        if let pick = candidates.randomElement() {
            return pick
        }

        return fallback(allowedStrings: allowedStrings, maxFret: maxFret)
    }

    private func fallback(allowedStrings: Set<Int>, maxFret: Int) -> (Note, FretPosition) {
        let cap = min(maxFret, GuitarFretboard.fretCount)
        for string in allowedStrings.sorted() {
            for fret in 0...cap {
                if let note = GuitarFretboard.note(at: string, fret: fret) {
                    return (note, FretPosition(string: string, fret: fret))
                }
            }
        }
        let note = Note(.a, octave: 3)
        return (note, FretPosition(string: 5, fret: 0))
    }
}
