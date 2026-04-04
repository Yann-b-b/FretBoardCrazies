//
//  FretPositionSelection.swift
//  audio_listen
//
//  Pure rules for choosing among equivalent fretboard positions for the same target note.
//

import Foundation

enum FretPositionSelection {
    /// Chooses the lowest fret; ties break toward lower string number (1 = high E).
    static func preferredForPractice(_ positions: [FretPosition]) -> FretPosition? {
        positions.min { a, b in
            if a.fret != b.fret { return a.fret < b.fret }
            return a.string < b.string
        }
    }
}
