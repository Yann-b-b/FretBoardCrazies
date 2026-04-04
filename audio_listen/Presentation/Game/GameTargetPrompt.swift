//
//  GameTargetPrompt.swift
//  audio_listen
//
//  Single source of truth for in-game target copy (note letter + string while playing).
//

import Foundation

enum GameTargetPrompt {
    /// Playing/countdown line: note name without octave, e.g. "C string 4".
    static func playingLine(note: Note, string: Int) -> String {
        "\(note.name.displayName) string \(string)"
    }

    /// Same as `playingLine(note:string:)` but appends ` open` when the target is an open string (fret 0).
    static func playingLine(note: Note, position: FretPosition) -> String {
        let base = playingLine(note: note, string: position.string)
        if position.fret == 0 {
            return "\(base) open"
        }
        return base
    }
}
