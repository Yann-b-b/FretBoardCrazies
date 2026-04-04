//
//  MaxFretProviding.swift
//  audio_listen
//
//  Supplies the inclusive upper fret bound for target generation (e.g. 12 vs full board).
//

import Foundation

/// Provides the maximum fret index allowed for randomly chosen targets.
protocol MaxFretProviding {
    var maxFretInclusive: Int { get }
}
