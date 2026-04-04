//
//  RandomNoteStrategy.swift
//  audio_listen
//
//  Strategy: picks random note in playable range, then random valid (string, fret) position.
//

import Foundation

/// Strategy that picks a random note and a random valid fret position.
struct RandomNoteStrategy: NoteGeneratorProtocol {
    private static let limitFretsKey = "limitFretsToTwelve"

    func nextTarget() -> (Note, FretPosition) {
        let notes = GuitarFretboard.playableNotes
        let maxFret = UserDefaults.standard.bool(forKey: Self.limitFretsKey) ? 12 : GuitarFretboard.fretCount

        for _ in 0..<64 {
            guard let note = notes.randomElement() else { break }
            let positions = GuitarFretboard.positions(for: note, maxFretInclusive: maxFret)
            if let position = positions.randomElement() {
                return (note, position)
            }
        }

        let fallback = Note(.a, octave: 3)
        let positions = GuitarFretboard.positions(for: fallback, maxFretInclusive: maxFret)
        let position = positions.randomElement() ?? FretPosition(string: 5, fret: 0)
        return (fallback, position)
    }
}
