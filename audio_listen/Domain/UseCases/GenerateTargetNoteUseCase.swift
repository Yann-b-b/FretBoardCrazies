//
//  GenerateTargetNoteUseCase.swift
//  audio_listen
//
//  Use case: generate the next target note for the game.
//

import Foundation

/// Use case for generating the next target note and fret position.
struct GenerateTargetNoteUseCase {
    private let noteGenerator: NoteGeneratorProtocol
    
    init(noteGenerator: NoteGeneratorProtocol) {
        self.noteGenerator = noteGenerator
    }
    
    func execute() -> (Note, FretPosition) {
        noteGenerator.nextTarget()
    }
}
