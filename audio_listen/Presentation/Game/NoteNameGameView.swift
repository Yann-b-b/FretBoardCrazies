//
//  NoteNameGameView.swift
//  audio_listen
//
//  Note-name practice: user picks pitch classes; each round randomizes string (and fret).
//

import SwiftUI

struct NoteNameGameView: View {
    @StateObject private var viewModel: GameViewModel
    private let allowedNoteNamesStore: GameAllowedNoteNamesStore

    @State private var allowedNoteNames: Set<NoteName> = Set(NoteName.allCases)

    init(viewModel: GameViewModel, allowedNoteNamesStore: GameAllowedNoteNamesStore) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.allowedNoteNamesStore = allowedNoteNamesStore
    }

    private static let noteOrder: [NoteName] = NoteName.allCases.sorted { $0.rawValue < $1.rawValue }

    var body: some View {
        VStack(spacing: 24) {
            Text("Find the note")
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
            allowedNoteNames = allowedNoteNamesStore.load()
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
                Text("Notes to practice")
                    .font(.headline)
                ForEach(Self.noteOrder, id: \.self) { name in
                    Toggle(name.displayName, isOn: bindingForNoteName(name))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if allowedNoteNames.isEmpty {
                Text("Turn on at least one note to start.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button("Start") {
                viewModel.startGame()
            }
            .buttonStyle(.borderedProminent)
            .disabled(allowedNoteNames.isEmpty)

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

    private func bindingForNoteName(_ name: NoteName) -> Binding<Bool> {
        Binding(
            get: { allowedNoteNames.contains(name) },
            set: { on in
                if on {
                    allowedNoteNames.insert(name)
                } else {
                    allowedNoteNames.remove(name)
                }
                allowedNoteNamesStore.save(allowedNoteNames)
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
            Text(GameTargetPrompt.playingLine(note: note, position: position))
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
            Text(GameTargetPrompt.playingLine(note: note, position: position))
                .font(.system(size: 40, weight: .bold))
                .multilineTextAlignment(.center)
            Text(position.displayString)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
