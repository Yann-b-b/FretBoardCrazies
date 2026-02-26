//
//  FretPosition.swift
//  audio_listen
//
//  Represents a position on the guitar fretboard (string + fret).
//

import Foundation

/// A position on the guitar: which string (1-6, 1=high E) and which fret (0=open).
struct FretPosition: Hashable, Equatable {
    /// String number 1-6 (1 = high E, 6 = low E)
    let string: Int
    /// Fret number (0 = open string)
    let fret: Int
    
    var displayString: String {
        if fret == 0 {
            return "String \(string), Open"
        } else {
            return "String \(string), Fret \(fret)"
        }
    }
}
