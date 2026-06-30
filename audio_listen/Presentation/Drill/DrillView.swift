import SwiftUI

struct DrillView: View {
    @StateObject private var viewModel: DrillViewModel
    private let allowedStringsStore: GameAllowedStringsStore

    @State private var allowedStrings: Set<Int> = Set(1...6)
    @State private var comboSound = ComboSoundPlayer()

    init(viewModel: DrillViewModel, allowedStringsStore: GameAllowedStringsStore) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.allowedStringsStore = allowedStringsStore
    }

    var body: some View {
        VStack(spacing: 20) {
            header
            comboBadge
            if let error = viewModel.errorMessage {
                Text(error).foregroundStyle(.red).multilineTextAlignment(.center)
            }
            content
        }
        .padding(24)
        .frame(minWidth: 640, minHeight: 480)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Image("bg-drill")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        )
        .onAppear { allowedStrings = allowedStringsStore.load() }
        .onChange(of: viewModel.comboCount) { oldValue, newValue in
            if newValue > oldValue {
                comboSound.play(combo: newValue)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("Fretboard Drill").font(.title2).bold()
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: viewModel.beltRank.belt.symbolName)
                    .foregroundStyle(viewModel.beltRank.belt.color)
                Text("\(viewModel.beltRank.belt.displayName) belt")
                    .foregroundStyle(.secondary)
            }
            Text("Today: \(viewModel.todayCount)").foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var comboBadge: some View {
        if viewModel.comboCount >= 2 {
            let scale = min(1.0 + Double(viewModel.comboCount) * 0.05, 1.6)
            Text("🔥 \(viewModel.comboCount) combo")
                .font(.headline)
                .foregroundStyle(.orange)
                .scaleEffect(scale)
                .animation(.spring(response: 0.25, dampingFraction: 0.5), value: viewModel.comboCount)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            idleSetup
        case .countdown(let remaining, let prompt):
            promptView(prompt, reveal: false)
            Text("\(remaining)").font(.system(size: 56, weight: .bold))
            controlButtons
        case .playing(_, let prompt):
            promptView(prompt, reveal: false)
            Text("Detected: \(viewModel.detectedNote)").foregroundStyle(.secondary)
            controlButtons
        case .success(let time, let prompt):
            promptView(prompt, reveal: true)
            Text("Correct!  \(String(format: "%.2f s", time))").foregroundStyle(.green).bold()
            controlButtons
        }
    }

    private var idleSetup: some View {
        VStack(spacing: 16) {
            Text("Pick strings, then press Space to start").foregroundStyle(.secondary)
            HStack {
                ForEach(StringSetPresets.all) { preset in
                    Button(preset.label) {
                        allowedStrings = preset.strings
                        allowedStringsStore.save(preset.strings)
                    }
                    .buttonStyle(.bordered)
                }
            }
            FretboardView(heatmap: [:])
            Button("Start") { viewModel.start() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.space, modifiers: [])
                .disabled(allowedStrings.isEmpty)
        }
    }

    private func promptView(_ prompt: DrillPrompt, reveal: Bool) -> some View {
        VStack(spacing: 12) {
            switch prompt.direction {
            case .findPosition:
                Text("\(prompt.targetNote.name.displayName) — string \(prompt.string)")
                    .font(.system(size: 48, weight: .bold))
                FretboardView(
                    highlightedString: prompt.string,
                    highlightedPosition: reveal ? position(for: prompt) : nil,
                    revealLabel: reveal ? prompt.targetNote.name.displayName : nil
                )
            case .nameNote:
                Text(reveal ? prompt.targetNote.name.displayName : "Name this note")
                    .font(.system(size: 40, weight: .bold))
                FretboardView(
                    highlightedPosition: position(for: prompt),
                    revealLabel: reveal ? prompt.targetNote.name.displayName : nil
                )
            }
        }
    }

    private func position(for prompt: DrillPrompt) -> FretPosition? {
        GuitarFretboard.positions(for: prompt.targetNote)
            .first { $0.string == prompt.string }
    }

    private var controlButtons: some View {
        HStack(spacing: 16) {
            Button("Skip") { viewModel.skip() }
                .keyboardShortcut("s", modifiers: [])
            Button("End") { viewModel.stop() }
                .keyboardShortcut(.cancelAction)
                .tint(.red)
            Button("Next") { viewModel.start() }
                .keyboardShortcut(.space, modifiers: [])
        }
    }
}
