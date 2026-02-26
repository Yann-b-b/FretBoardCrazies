//
//  GameRound.swift
//  audio_listen
//
//  Represents a completed game round for scoring.
//

import Foundation

/// A completed round: target note, whether correct, and reaction time.
struct GameRound {
    let targetNote: Note
    let targetPosition: FretPosition
    let wasCorrect: Bool
    let reactionTime: TimeInterval?
}
