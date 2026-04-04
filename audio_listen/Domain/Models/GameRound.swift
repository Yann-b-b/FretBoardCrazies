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
    /// Distinct wrong stable detections before a correct hit (legacy rounds default to 0).
    let wrongAttemptsBeforeSuccess: Int

    init(
        targetNote: Note,
        targetPosition: FretPosition,
        reactionTime: TimeInterval,
        playedAt: Date,
        wrongAttemptsBeforeSuccess: Int = 0
    ) {
        self.targetNote = targetNote
        self.targetPosition = targetPosition
        self.reactionTime = reactionTime
        self.playedAt = playedAt
        self.wrongAttemptsBeforeSuccess = wrongAttemptsBeforeSuccess
    }
}
