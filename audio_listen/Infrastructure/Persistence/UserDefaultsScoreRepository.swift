//
//  UserDefaultsScoreRepository.swift
//  audio_listen
//
//  Persists game rounds to UserDefaults.
//

import Foundation

/// Repository implementation using UserDefaults.
final class UserDefaultsScoreRepository: ScoreRepositoryProtocol {
    private let key = "audio_listen_game_rounds"
    private let maxStored = 100
    
    func save(round: GameRound) {
        var rounds = loadRounds()
        rounds.append(round)
        if rounds.count > maxStored {
            rounds = Array(rounds.suffix(maxStored))
        }
        saveRounds(rounds)
    }
    
    func bestTimes() -> [Note: TimeInterval] {
        let rounds = loadRounds().filter { $0.wasCorrect && $0.reactionTime != nil }
        var best: [Note: TimeInterval] = [:]
        for round in rounds {
            guard let time = round.reactionTime else { continue }
            if best[round.targetNote] == nil || time < best[round.targetNote]! {
                best[round.targetNote] = time
            }
        }
        return best
    }
    
    func averageTime(forRounds count: Int) -> TimeInterval? {
        let rounds = loadRounds()
            .filter { $0.wasCorrect && $0.reactionTime != nil }
            .suffix(count)
        guard !rounds.isEmpty else { return nil }
        let sum = rounds.compactMap(\.reactionTime).reduce(0, +)
        return sum / Double(rounds.count)
    }
    
    private func loadRounds() -> [GameRound] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([CodableGameRound].self, from: data) else {
            return []
        }
        return decoded.map(\.toGameRound)
    }
    
    private func saveRounds(_ rounds: [GameRound]) {
        let codable = rounds.map(CodableGameRound.init)
        if let data = try? JSONEncoder().encode(codable) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

private struct CodableGameRound: Codable {
    let targetNoteNameRawValue: Int
    let targetNoteOctave: Int
    let targetString: Int
    let targetFret: Int
    let wasCorrect: Bool
    let reactionTime: TimeInterval?
    
    init(from round: GameRound) {
        targetNoteNameRawValue = round.targetNote.name.rawValue
        targetNoteOctave = round.targetNote.octave
        targetString = round.targetPosition.string
        targetFret = round.targetPosition.fret
        wasCorrect = round.wasCorrect
        reactionTime = round.reactionTime
    }
    
    var toGameRound: GameRound {
        let name = NoteName(rawValue: targetNoteNameRawValue) ?? .a
        let note = Note(name, octave: targetNoteOctave)
        let position = FretPosition(string: targetString, fret: targetFret)
        return GameRound(targetNote: note, targetPosition: position, wasCorrect: wasCorrect, reactionTime: reactionTime)
    }
}
