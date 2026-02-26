//
//  GuitarFretboard.swift
//  audio_listen
//
//  Standard tuning fretboard model: note at (string, fret) and all positions for a note.
//

import Foundation

/// Standard guitar tuning (E2, A2, D3, G3, B3, E4). String 1 = high E, String 6 = low E.
struct GuitarFretboard {
    static let fretCount = 24
    
    /// Base notes for each string (string 1 = index 0, string 6 = index 5)
    private static let standardTuning: [Note] = [
        Note(.e, octave: 4),  // String 1 - high E
        Note(.b, octave: 3),
        Note(.g, octave: 3),
        Note(.d, octave: 3),
        Note(.a, octave: 2),
        Note(.e, octave: 2)   // String 6 - low E
    ]
    
    /// Note at (string, fret). String 1-6, fret 0 = open.
    static func note(at string: Int, fret: Int) -> Note? {
        guard string >= 1, string <= 6, fret >= 0, fret <= fretCount else { return nil }
        let baseNote = standardTuning[string - 1]
        let midiOffset = baseNote.midiNumber + fret
        return Note.from(midiNumber: midiOffset)
    }
    
    /// All (string, fret) positions that produce the given note.
    static func positions(for note: Note) -> [FretPosition] {
        let targetMidi = note.midiNumber
        var result: [FretPosition] = []

        // loop through all strings and frets and check if note is at that position
        for string in 1...6 {



            //get midi number of the base note for the string
            let baseMidi = standardTuning[string-1].midiNumber 

            let fret = targetMidi - baseMidi

            if fret >= 0 && fret <= fretCount {
                result.append(FretPosition(string: string, fret: fret))
            }
        }
        return result
    } 
    
    /// Playable note range for the game (E2 to E5)
    static var playableNotes: [Note] {
        let minMidi = Note(.e, octave: 2).midiNumber
        let maxMidi = Note(.e, octave: 5).midiNumber
        return (minMidi...maxMidi).compactMap { Note.from(midiNumber: $0) }
    }
}

// MARK: - Note MIDI conversion

extension Note {
    /// Create a Note from MIDI note number.
    static func from(midiNumber: Int) -> Note? {
        guard midiNumber >= 0, midiNumber <= 127 else { return nil }
        let semitones = ((midiNumber % 12) + 12) % 12
        guard let name = NoteName(rawValue: semitones) else { return nil }
        let octave = (midiNumber / 12) - 1
        return Note(name, octave: octave)
    }
}
