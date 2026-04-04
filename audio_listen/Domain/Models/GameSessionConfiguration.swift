//
//  GameSessionConfiguration.swift
//  audio_listen
//
//  Per-session options for the note game (setup UI and generator wiring come later).
//

import Foundation

/// Configuration for a game session: display hints and which strings may be targeted.
struct GameSessionConfiguration: Equatable, Codable {
    /// When `true`, show note name and string/fret; when `false`, show note only.
    var showStringAndFret: Bool
    /// Guitar strings 1...6 (1 = high E, 6 = low E).
    var allowedStrings: Set<Int>

    init(showStringAndFret: Bool = true, allowedStrings: Set<Int>) {
        self.showStringAndFret = showStringAndFret
        self.allowedStrings = allowedStrings
    }

    /// Default: all strings, full position hint — matches pre-setup-screen behavior.
    static func defaultAllStrings() -> GameSessionConfiguration {
        GameSessionConfiguration(showStringAndFret: true, allowedStrings: Set(1...6))
    }

    enum ValidationError: Error, Equatable {
        case emptyAllowedStrings
        case stringOutOfRange(Int)
    }

    /// Returns `self` if valid; otherwise throws.
    func validated() throws -> GameSessionConfiguration {
        guard !allowedStrings.isEmpty else { throw ValidationError.emptyAllowedStrings }
        for s in allowedStrings {
            guard (1...6).contains(s) else { throw ValidationError.stringOutOfRange(s) }
        }
        return self
    }

    var isValid: Bool {
        (try? validated()) != nil
    }
}
