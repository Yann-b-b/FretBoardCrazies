//
//  PitchDetectorProtocol.swift
//  audio_listen
//
//  Protocol for real-time pitch detection from microphone.
//

import Combine
import Foundation

/// Protocol for pitch detection. Implementations wrap AudioKit or other audio engines.
protocol PitchDetectorProtocol: AnyObject {
    /// Stream of detected pitches (note, frequency, amplitude). Emits when a valid note is detected.
    var currentPitch: AnyPublisher<DetectedPitch, Never> { get }
    
    /// Start listening to the microphone.
    func start() throws
    
    /// Stop listening.
    func stop()
}
