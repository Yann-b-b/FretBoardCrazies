//
//  GameStateMachine.swift
//  audio_listen
//
//  Handles game state transitions and side effects.
//

import Foundation

/// Callbacks for state machine side effects.
struct GameStateMachineCallbacks {
    var onSuccess: ((TimeInterval) -> Void)?
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
        case (.idle, .countdown), (.idle, .playing):
            break
        case (.countdown, .playing):
            break
        case (.playing, .success):
            break
        case (.success, .playing):
            break
        case (.playing, .idle), (.success, .idle):
            break
        default:
            return false
        }
        state = newState
        
        switch newState {
        case .success(let time, _, _):
            callbacks.onSuccess?(time)
        default:
            break
        }
        return true
    }
}
