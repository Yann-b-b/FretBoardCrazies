//
//  PitchError.swift
//  audio_listen
//
//  Errors for pitch detection.
//

import Foundation

enum PitchError: Error {
    case belowThreshold
    case invalidFrequency
}
