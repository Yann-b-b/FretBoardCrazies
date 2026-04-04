//
//  NoteMetrics.swift
//  audio_listen
//
//  Pure aggregation over persisted game rounds.
//

import Foundation

enum NoteMetrics {
    /// Average `wrongAttemptsBeforeSuccess` per distinct target note (octave-specific).
    static func averageWrongAttemptsPerTargetNote(rounds: [GameRound]) -> [Note: Double] {
        guard !rounds.isEmpty else { return [:] }
        var sums: [Note: Int] = [:]
        var counts: [Note: Int] = [:]
        for round in rounds {
            sums[round.targetNote, default: 0] += round.wrongAttemptsBeforeSuccess
            counts[round.targetNote, default: 0] += 1
        }
        var result: [Note: Double] = [:]
        for note in sums.keys {
            let count = counts[note]!
            result[note] = Double(sums[note]!) / Double(count)
        }
        return result
    }
}
