//
//  AllowedStringsProviding.swift
//  audio_listen
//
//  Supplies which of the current instrument's string numbers may be targeted for the note game.
//

import Foundation

/// Provides the current set of allowed string numbers for target generation.
protocol AllowedStringsProviding {
    var allowedStrings: Set<Int> { get }
}
