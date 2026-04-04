//
//  ScoreRepositoryProtocol.swift
//  audio_listen
//
//  Protocol for persisting game scores.
//

import Foundation

/// Protocol for saving and retrieving game scores.
protocol ScoreRepositoryProtocol {
    /// Save a completed round.
    func save(round: GameRound)
    
    /// Best times per note (if tracked).
    func bestTimes() -> [Note: TimeInterval]
    
    /// Average reaction time over last N rounds.
    func averageTime(forRounds count: Int) -> TimeInterval?

    /// Mean wrong attempts before success, grouped by target note (all stored rounds).
    func averageWrongAttemptsByTargetNote() -> [Note: Double]
}
