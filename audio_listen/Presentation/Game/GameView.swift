//
//  GameView.swift
//  audio_listen
//
//  Main game view: target note, Go button, reaction time.
//

import SwiftUI

struct GameView: View {
    @StateObject private var viewModel: GameViewModel
    
    init(viewModel: GameViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Guitar Note Game")
                .font(.title)
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            
            gameContent
        }
        .padding()
    }
    
    @ViewBuilder
    private var gameContent: some View {
        switch viewModel.state {
        case .idle:
            Text("Tap Start to begin")
                .font(.title2)
                .foregroundStyle(.secondary)
            Button("Start") {
                viewModel.startRound()
            }
            .buttonStyle(.borderedProminent)
            
        case .ready(let note, let position):
            targetDisplay(note: note, position: position)
            Button("Go!") {
                viewModel.beginRound()
            }
            .buttonStyle(.borderedProminent)
            .font(.title2)
            
        case .countdown(let remaining, let note, let position):
            targetDisplay(note: note, position: position)
            Text("\(remaining)")
                .font(.system(size: 64, weight: .bold))
            
        case .playing(_, let note, let position):
            targetDisplay(note: note, position: position)
            Text("Playing...")
                .font(.title2)
            Text("Detected: \(viewModel.detectedNote)")
                .font(.headline)
                .foregroundStyle(.secondary)
            
        case .success(let time, let note, let position):
            targetDisplay(note: note, position: position)
            Text("Correct!")
                .font(.title)
                .foregroundStyle(.green)
            Text(String(format: "%.2f seconds", time))
                .font(.title2)
            Button("Next") {
                viewModel.nextRound()
            }
            .buttonStyle(.borderedProminent)
            
        case .timeout(let note, let position):
            targetDisplay(note: note, position: position)
            Text("Time's up!")
                .font(.title)
                .foregroundStyle(.orange)
            Button("Next") {
                viewModel.nextRound()
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private func targetDisplay(note: Note, position: FretPosition) -> some View {
        VStack(spacing: 8) {
            Text("Play")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(note.displayName)
                .font(.system(size: 56, weight: .bold))
            Text(position.displayString)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
