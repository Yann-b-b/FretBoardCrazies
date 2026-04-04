//
//  RandomNoteStrategy.swift
//  audio_listen
//
//  Strategy: picks random note in playable range, then random valid (string, fret) position.
//

import Foundation

/// Strategy that picks a random note and a valid fret position on allowed strings.
struct RandomNoteStrategy: NoteGeneratorProtocol {
    private let allowedStringsProvider: AllowedStringsProviding
    private let maxFretProvider: MaxFretProviding

    init(allowedStringsProvider: AllowedStringsProviding, maxFretProvider: MaxFretProviding) {
        self.allowedStringsProvider = allowedStringsProvider
        self.maxFretProvider = maxFretProvider
    }

    static func filterPositions(_ positions: [FretPosition], allowed: Set<Int>) -> [FretPosition] {
        positions.filter { allowed.contains($0.string) }
    }

    func nextTarget() -> (Note, FretPosition) {
        let rawAllowed = allowedStringsProvider.allowedStrings
        let allowed = rawAllowed.isEmpty ? Set(1...6) : rawAllowed

        let notes = GuitarFretboard.playableNotes
        let maxFret = maxFretProvider.maxFretInclusive

        for _ in 0..<64 {
            guard let note = notes.randomElement() else { break }
            let positions = Self.filterPositions(
                GuitarFretboard.positions(for: note, maxFretInclusive: maxFret),
                allowed: allowed
            )
            if let position = FretPositionSelection.preferredForPractice(positions) {
                return (note, position)
            }
        }

        return fallbackTarget(maxFret: maxFret, allowed: allowed)
    }

    /// Deterministic search for any playable (note, position) on allowed strings after random retries fail.
    private func fallbackTarget(maxFret: Int, allowed: Set<Int>) -> (Note, FretPosition) {
        let notes = GuitarFretboard.playableNotes
        for note in notes.shuffled() {
            let filtered = Self.filterPositions(
                GuitarFretboard.positions(for: note, maxFretInclusive: maxFret),
                allowed: allowed
            )
            if let position = FretPositionSelection.preferredForPractice(filtered) {
                return (note, position)
            }
        }
        let fallback = Note(.a, octave: 3)
        let filtered = Self.filterPositions(
            GuitarFretboard.positions(for: fallback, maxFretInclusive: maxFret),
            allowed: allowed
        )
        if let position = FretPositionSelection.preferredForPractice(filtered) {
            return (fallback, position)
        }
        for string in allowed.sorted() {
            if let note = GuitarFretboard.note(at: string, fret: 0) {
                return (note, FretPosition(string: string, fret: 0))
            }
        }
        return (fallback, FretPosition(string: 5, fret: 0))
    }
}
