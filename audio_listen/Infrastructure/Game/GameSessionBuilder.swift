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
    private var minAmplitude: Float = 0.01
    
    func countdown(_ enabled: Bool) -> GameSessionBuilder {
        var copy = self
        copy.countdownEnabled = enabled
        return copy
    }
    
    func amplitudeThreshold(_ value: Float) -> GameSessionBuilder {
        var copy = self
        copy.minAmplitude = value
        return copy
    }
    
    func build() -> GameSessionConfig {
        GameSessionConfig(
            countdownEnabled: countdownEnabled,
            minAmplitude: minAmplitude
        )
    }
}

/// Configuration for a game session.
struct GameSessionConfig {
    let countdownEnabled: Bool
    let minAmplitude: Float
}
