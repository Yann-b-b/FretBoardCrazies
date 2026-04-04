//
//  GameRound.swift
//  audio_listen
//
//  Represents a completed game round for scoring.
//

import Foundation

/// A completed round: target note, reaction time, and when it was recorded.
struct GameRound {
    let targetNote: Note
    let targetPosition: FretPosition
    let reactionTime: TimeInterval
    /// When the round was saved. Legacy persisted data without this field decodes as `Date.distantPast`.
    let playedAt: Date
}
