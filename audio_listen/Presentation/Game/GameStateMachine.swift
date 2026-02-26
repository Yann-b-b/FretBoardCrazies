//
//  GameStateMachine.swift
//  audio_listen
//
//  Handles game state transitions and side effects.
//

import Foundation

/// Callbacks for state machine side effects.
struct GameStateMachineCallbacks {
    var onPlayingStarted: (() -> Void)?
    var onSuccess: ((TimeInterval) -> Void)?
    var onTimeout: (() -> Void)?
}

/// State machine for game flow transitions.
final class GameStateMachine {
    private(set) var state: GameState = .idle
    private var callbacks = GameStateMachineCallbacks()
    
    func setCallbacks(_ callbacks: GameStateMachineCallbacks) {
        self.callbacks = callbacks
    }
    
    @discardableResult
    func transition(to newState: GameState) -> Bool {
        switch (state, newState) {
        case (.idle, .ready):
            break
        case (.ready, .countdown), (.ready, .playing):
            break
        case (.countdown, .playing):
            break
        case (.playing, .success), (.playing, .timeout):
            break
        case (.success, .idle), (.success, .ready), (.timeout, .idle), (.timeout, .ready):
            break
        default:
            return false
        }
        state = newState
        
        switch newState {
        case .playing:
            callbacks.onPlayingStarted?()
        case .success(let time, _, _):
            callbacks.onSuccess?(time)
        case .timeout:
            callbacks.onTimeout?()
        default:
            break
        }
        return true
    }
}
