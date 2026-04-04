//
//  GameTargetFretBounds.swift
//  audio_listen
//
//  Named bounds for target generation when "limited fret range" is enabled in Settings.
//

import Foundation

enum GameTargetFretBounds {
    /// Inclusive max fret when limiting is on (frets 0…11; excludes 12 to avoid open vs same-string octave duplicate prompts).
    static let limitedMaxFretInclusive = 11
}
