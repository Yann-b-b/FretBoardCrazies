//
//  ValidateNoteUseCase.swift
//  audio_listen
//
//  Use case: check if a detected note matches the target.
//

import Foundation

/// Use case for validating that a detected note matches the target.
struct ValidateNoteUseCase {
    func execute(detected: Note, target: Note) -> Bool {
        detected == target
    }
}
