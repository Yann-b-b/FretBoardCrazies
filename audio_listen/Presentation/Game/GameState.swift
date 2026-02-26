//
//  GameState.swift
//  audio_listen
//
//  State machine states for the game flow.
//

import Foundation

/// Game state with associated values for each phase.
enum GameState: Equatable {
    case idle
    case ready(targetNote: Note, targetPosition: FretPosition)
    case countdown(remaining: Int, targetNote: Note, targetPosition: FretPosition)
    case playing(startTime: Date, targetNote: Note, targetPosition: FretPosition)
    case success(time: TimeInterval, targetNote: Note, targetPosition: FretPosition)
    case timeout(targetNote: Note, targetPosition: FretPosition)
}
