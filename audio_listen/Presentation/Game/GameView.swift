//
//  GameView.swift
//  audio_listen
//
//  Main game view: continuous note recognition game.
//

import SwiftUI

struct GameView: View {
    @StateObject private var viewModel: GameViewModel
    private let allowedStringsStore: GameAllowedStringsStore

    @State private var allowedStrings: Set<Int> = Set(1...6)

    init(viewModel: GameViewModel, allowedStringsStore: GameAllowedStringsStore) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.allowedStringsStore = allowedStringsStore
    }

    private static let stringLabels: [(number: Int, name: String)] = [
        (1, "high E"), (2, "B"), (3, "G"), (4, "D"), (5, "A"), (6, "low E")
    ]
    
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
        .onAppear {
            allowedStrings = allowedStringsStore.load()
        }
    }

    @ViewBuilder
    private var gameContent: some View {
        switch viewModel.state {
        case .idle:
            Text("Tap Start to begin")
                .font(.title2)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Strings to practice")
                    .font(.headline)
                ForEach(Self.stringLabels, id: \.number) { row in
                    Toggle("\(row.number) — \(row.name)", isOn: bindingForString(row.number))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if allowedStrings.isEmpty {
                Text("Turn on at least one string to start.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button("Start") {
                viewModel.startGame()
            }
            .buttonStyle(.borderedProminent)
            .disabled(allowedStrings.isEmpty)
            
        case .countdown(let remaining, let note, let position):
            playingTargetView(note: note, position: position)
            Text("\(remaining)")
                .font(.system(size: 64, weight: .bold))
            endButton
            
        case .playing(_, let note, let position):
            playingTargetView(note: note, position: position)
            Text("Detected: \(viewModel.detectedNote)")
                .font(.headline)
                .foregroundStyle(.secondary)
            endButton
            
        case .success(let time, let note, let position):
            successTargetView(note: note, position: position)
            Text("Correct!")
                .font(.title)
                .foregroundStyle(.green)
            Text(String(format: "%.2f seconds", time))
                .font(.title2)
            endButton
        }
    }
    
    private func bindingForString(_ string: Int) -> Binding<Bool> {
        Binding(
            get: { allowedStrings.contains(string) },
            set: { on in
                if on {
                    allowedStrings.insert(string)
                } else {
                    allowedStrings.remove(string)
                }
                allowedStringsStore.save(allowedStrings)
            }
        )
    }

    private var endButton: some View {
        Button("End") {
            viewModel.stopGame()
        }
        .buttonStyle(.bordered)
        .tint(.red)
    }
    
    private func playingTargetView(note: Note, position: FretPosition) -> some View {
        VStack(spacing: 8) {
            Text("Play")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(GameTargetPrompt.playingLine(note: note, string: position.string))
                .font(.system(size: 56, weight: .bold))
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private func successTargetView(note: Note, position: FretPosition) -> some View {
        VStack(spacing: 8) {
            Text("Play")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(GameTargetPrompt.playingLine(note: note, string: position.string))
                .font(.system(size: 40, weight: .bold))
                .multilineTextAlignment(.center)
            Text(position.displayString)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
