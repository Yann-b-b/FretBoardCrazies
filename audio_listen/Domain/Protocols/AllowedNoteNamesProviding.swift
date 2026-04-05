//
//  AllowedNoteNamesProviding.swift
//  audio_listen
//
//  Supplies which chromatic note names may be targeted in note-name practice mode.
//

import Foundation

/// Provides the current set of allowed `NoteName` values (pitch classes) for generation.
protocol AllowedNoteNamesProviding {
    var allowedNoteNames: Set<NoteName> { get }
}
