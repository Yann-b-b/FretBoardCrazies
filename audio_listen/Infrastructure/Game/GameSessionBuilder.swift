//
//  GameSessionBuilder.swift
//  audio_listen
//
//  Builder for configuring game session parameters.
//

import Foundation

/// Fluent builder for game session configuration.
struct GameSessionBuilder {
    private var countdownEnabled = false
    
    func countdown(_ enabled: Bool) -> GameSessionBuilder {
        var copy = self
        copy.countdownEnabled = enabled
        return copy
    }
    
    func build() -> GameSessionConfig {
        GameSessionConfig(countdownEnabled: countdownEnabled)
    }
}

/// Configuration for a game session.
struct GameSessionConfig {
    let countdownEnabled: Bool
}
