//
//  Note.swift
//  audio_listen
//
//  Domain model representing a musical note with name and octave.
//

import Foundation

/// A musical note with name (A-G, including sharps/flats) and octave.
struct Note: Hashable, Equatable {
    let name: NoteName
    let octave: Int
    
    /// Display string, e.g. "A4", "C#3"
    var displayName: String {
        name.displayName + "\(octave)"
    }
    
    /// MIDI note number (A4 = 69)
    var midiNumber: Int {
        name.semitonesFromC + (octave + 1) * 12
    }
    
    /// Frequency in Hz (equal temperament, A4 = 440 Hz)
    var frequency: Double {
        440.0 * pow(2.0, Double(midiNumber - 69) / 12.0)
    }
    
    init(_ name: NoteName, octave: Int) {
        self.name = name
        self.octave = octave
    }
}

/// Note name without octave (12 chromatic notes)
enum NoteName: Int, CaseIterable, Hashable {
    case c = 0
    case cSharp
    case d
    case dSharp
    case e
    case f
    case fSharp
    case g
    case gSharp
    case a
    case aSharp
    case b
    
    /// Semitones above C in the same octave (C=0, C#=1, ..., B=11)
    var semitonesFromC: Int { rawValue }
    
    /// Display string, e.g. "C", "C#", "Eb"
    var displayName: String {
        switch self {
        case .c: return "C"
        case .cSharp: return "C#"
        case .d: return "D"
        case .dSharp: return "D#"
        case .e: return "E"
        case .f: return "F"
        case .fSharp: return "F#"
        case .g: return "G"
        case .gSharp: return "G#"
        case .a: return "A"
        case .aSharp: return "A#"
        case .b: return "B"
        }
    }
}
