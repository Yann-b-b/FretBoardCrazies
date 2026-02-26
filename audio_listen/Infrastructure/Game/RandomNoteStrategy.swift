//
//  RandomNoteStrategy.swift
//  audio_listen
//
//  Strategy: picks random note in playable range, then random valid (string, fret) position.
//

import Foundation

/// Strategy that picks a random note and a random valid fret position.
struct RandomNoteStrategy: NoteGeneratorProtocol {
    func nextTarget() -> (Note, FretPosition) {
        let notes = GuitarFretboard.playableNotes
        guard let note = notes.randomElement() else {
            return (Note(.a, octave: 3), FretPosition(string: 5, fret: 0))
        }
        let positions = GuitarFretboard.positions(for: note)
        let position = positions.randomElement() ?? FretPosition(string: 5, fret: 0)
        return (note, position)
    }
}
