//
//  GameSessionBuilder.swift
//  audio_listen
//
//  Builder for configuring game session parameters.
//

import Foundation

/// Fluent builder for game session configuration.
struct GameSessionBuilder {
    private var timeoutSeconds: TimeInterval = 5
    private var countdownEnabled = false
    private var minAmplitude: Float = 0.01
    
    func timeout(_ seconds: TimeInterval) -> GameSessionBuilder {
        var copy = self
        copy.timeoutSeconds = seconds
        return copy
    }
    
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
            timeoutSeconds: timeoutSeconds,
            countdownEnabled: countdownEnabled,
            minAmplitude: minAmplitude
        )
    }
}

/// Configuration for a game session.
struct GameSessionConfig {
    let timeoutSeconds: TimeInterval
    let countdownEnabled: Bool
    let minAmplitude: Float
}
