import SwiftUI

struct DrillView: View {
    @StateObject private var viewModel: DrillViewModel
    private let allowedStringsStore: GameAllowedStringsStore

    @State private var allowedStrings: Set<Int> = Set(1...6)
    @State private var comboSound = ComboSoundPlayer()
    @State private var checkPop = false
    @State private var beltBurst = false
    @State private var beltPulse = false
    @AppStorage(GameSettingsKeys.touchMode) private var touchMode = false

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
        #if os(macOS)
        .frame(minWidth: 640, minHeight: 480)
        #endif
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
        .onChange(of: viewModel.beltRank.belt) { oldBelt, newBelt in
            guard newBelt.outranks(oldBelt) else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                beltBurst = true
                beltPulse = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeOut(duration: 0.4)) {
                    beltBurst = false
                    beltPulse = false
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("Fretboard Drill").font(.title2).bold()
            Spacer()
            HStack(spacing: 6) {
                Image(viewModel.beltRank.belt.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 32)
                    .scaleEffect(beltPulse ? 1.3 : 1.0)
                    .overlay {
                        Image("combo-burst")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 64)
                            .opacity(beltBurst ? 1 : 0)
                            .scaleEffect(beltBurst ? 1.2 : 0.6)
                            .allowsHitTesting(false)
                    }
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
            HStack(spacing: 6) {
                Image(flameAsset(for: viewModel.comboCount))
                    .resizable()
                    .scaledToFit()
                    .frame(height: 24)
                Text("\(viewModel.comboCount) combo")
                    .font(.headline)
                    .foregroundStyle(.orange)
            }
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
            HStack(spacing: 8) {
                Image("correct-sticker")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 28)
                    .scaleEffect(checkPop ? 1.0 : 0.5)
                    .opacity(checkPop ? 1 : 0)
                    .onAppear {
                        checkPop = false
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { checkPop = true }
                    }
                Text("Correct!  \(String(format: "%.2f s", time))").foregroundStyle(.green).bold()
            }
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
                    revealLabel: reveal ? prompt.targetNote.name.displayName : nil,
                    onTap: (touchMode && !reveal) ? { viewModel.submitTouch($0) } : nil,
                    wrongPosition: reveal ? nil : viewModel.lastWrongPosition
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
