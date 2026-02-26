//
//  DetectedPitch.swift
//  audio_listen
//
//  Represents a pitch detected from audio input.
//

import Foundation

/// A pitch detected from the microphone (note, frequency, amplitude).
struct DetectedPitch {
    let note: Note
    let frequency: Double
    let amplitude: Float
}
