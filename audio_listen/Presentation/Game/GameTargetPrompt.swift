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
}
