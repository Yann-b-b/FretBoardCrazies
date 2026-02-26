//
//  NoteConverter.swift
//  audio_listen
//
//  Converts frequency (Hz) to Note using equal temperament (A4 = 440 Hz).
//

import Foundation

enum NoteConverter {
    /// Convert frequency to nearest note. Returns nil if below amplitude threshold or out of range.
    static func frequencyToNote(_ frequency: Double, amplitude: Float, minAmplitude: Float = 0.01) -> Result<Note, PitchError> {
        guard amplitude >= minAmplitude else { return .failure(.belowThreshold) }
        guard frequency >= 20, frequency <= 4000 else { return .failure(.invalidFrequency) }
        
        // MIDI note: 69 = A4 = 440 Hz
        let midiFloat = 69 + 12 * log2(frequency / 440.0)
        let midiNumber = Int(round(midiFloat))
        guard let note = Note.from(midiNumber: midiNumber) else { return .failure(.invalidFrequency) }
        
        return .success(note)
    }
}
