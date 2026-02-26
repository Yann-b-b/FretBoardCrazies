//
//  NoteGeneratorProtocol.swift
//  audio_listen
//
//  Protocol for generating target notes for the game.
//

import Foundation

/// Protocol for generating the next target note and fret position.
protocol NoteGeneratorProtocol {
    /// Returns the next (note, fret position) for the user to play.
    func nextTarget() -> (Note, FretPosition)
}
