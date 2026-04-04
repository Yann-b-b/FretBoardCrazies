//
//  WrongAttemptCounter.swift
//  audio_listen
//
//  Counts distinct wrong stable detections per round (one increment per contiguous wrong note).
//

import Foundation

struct WrongAttemptCounter {
    private var lastWrongNote: Note?
    private(set) var wrongAttemptsBeforeSuccess: Int = 0

    mutating func reset() {
        lastWrongNote = nil
        wrongAttemptsBeforeSuccess = 0
    }

    /// Records a failed validation after a stable pitch event. Ignores correct matches.
    mutating func registerDetection(target: Note, detected: Note) {
        guard detected != target else { return }
        if lastWrongNote != detected {
            lastWrongNote = detected
            wrongAttemptsBeforeSuccess += 1
        }
    }
}
