import SwiftUI

struct DrillView: View {
    @StateObject private var viewModel: DrillViewModel
    private let allowedStringsStore: GameAllowedStringsStore

    @State private var allowedStrings: Set<Int> = StringSetPresets.defaultStrings
    @State private var comboSound = ComboSoundPlayer()
    @State private var checkPop = false
    @State private var beltBurst = false
    @State private var beltPulse = false
    @AppStorage(GameSettingsKeys.touchMode) private var touchMode = false
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var compact: Bool { verticalSizeClass == .compact }
    private var fretboardHeight: CGFloat { compact ? 150 : 220 }
    private var beltHeight: CGFloat { compact ? 44 : 96 }
    private var burstHeight: CGFloat { compact ? 80 : 160 }
    private var flameHeight: CGFloat { compact ? 36 : 80 }
    private var correctHeight: CGFloat { compact ? 40 : 80 }
    private var statusHeight: CGFloat { compact ? 48 : 80 }

    private var stringChoiceSelection: Binding<String> {
        Binding(
            get: { StringSetPresets.choices.first { $0.strings == allowedStrings }?.id ?? StringSetPresets.defaultChoice.id },
            set: { id in
                guard let choice = StringSetPresets.choices.first(where: { $0.id == id }) else { return }
                allowedStrings = choice.strings
                allowedStringsStore.save(choice.strings)
            }
        )
    }

    init(viewModel: DrillViewModel, allowedStringsStore: GameAllowedStringsStore) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.allowedStringsStore = allowedStringsStore
    }

    var body: some View {
        VStack(spacing: compact ? 10 : 20) {
            header
            comboBadge
            if let error = viewModel.errorMessage {
                Text(error).foregroundStyle(.red).multilineTextAlignment(.center)
            }
            content
        }
        .padding(compact ? 12 : 24)
        #if os(macOS)
        .frame(minWidth: 640, minHeight: 480)
        #endif
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: compact ? .top : .center)
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
                    .frame(height: beltHeight)
                    .scaleEffect(beltPulse ? 1.3 : 1.0)
                    .overlay {
                        Image("combo-burst")
                            .resizable()
                            .scaledToFit()
                            .frame(height: burstHeight)
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

    private var comboBadge: some View {
        let showing = viewModel.comboCount >= 2
        let scale = min(1.0 + Double(viewModel.comboCount) * 0.05, 1.6)
        return HStack(spacing: 6) {
            Image(flameAsset(for: max(viewModel.comboCount, 2)))
                .resizable()
                .scaledToFit()
                .frame(height: flameHeight)
            Text("\(viewModel.comboCount) combo")
                .font(.headline)
                .foregroundStyle(.orange)
        }
        .scaleEffect(scale)
        .opacity(showing ? 1 : 0)
        .frame(height: flameHeight)
        .animation(.spring(response: 0.25, dampingFraction: 0.5), value: viewModel.comboCount)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            idleSetup
        case .countdown(let remaining, let prompt):
            promptView(prompt, reveal: false)
            Text("\(remaining)").font(.system(size: compact ? 40 : 56, weight: .bold))
                .frame(height: statusHeight)
            controlButtons
        case .playing(_, let prompt):
            promptView(prompt, reveal: false)
            Text("Detected: \(viewModel.detectedNote)").foregroundStyle(.secondary)
                .frame(height: statusHeight)
            controlButtons
        case .success(let time, let prompt):
            promptView(prompt, reveal: true)
            HStack(spacing: 8) {
                Image("correct-sticker")
                    .resizable()
                    .scaledToFit()
                    .frame(height: correctHeight)
                    .scaleEffect(checkPop ? 1.0 : 0.5)
                    .opacity(checkPop ? 1 : 0)
                    .onAppear {
                        checkPop = false
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { checkPop = true }
                    }
                Text("Correct!  \(String(format: "%.2f s", time))").foregroundStyle(.green).bold()
            }
            .frame(height: statusHeight)
            controlButtons
        }
    }

    private var idleSetup: some View {
        VStack(spacing: 16) {
            Text("Pick strings, then press Space to start").foregroundStyle(.secondary)
            Picker("Strings", selection: stringChoiceSelection) {
                Section("Presets") {
                    ForEach(StringSetPresets.all) { Text($0.label).tag($0.id) }
                }
                Section("Single string") {
                    ForEach(StringSetPresets.singles) { Text($0.label).tag($0.id) }
                }
            }
            .pickerStyle(.menu)
            FretboardView(heatmap: [:], minHeight: fretboardHeight)
            Button("Start") { viewModel.start() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.space, modifiers: [])
                .disabled(allowedStrings.isEmpty)
        }
    }

    private func promptView(_ prompt: DrillPrompt, reveal: Bool) -> some View {
        VStack(spacing: compact ? 8 : 12) {
            switch prompt.direction {
            case .findPosition:
                Text("\(prompt.targetNote.name.displayName) — string \(prompt.string)")
                    .font(.system(size: compact ? 30 : 48, weight: .bold))
                FretboardView(
                    highlightedString: prompt.string,
                    highlightedPosition: reveal ? position(for: prompt) : nil,
                    revealLabel: reveal ? prompt.targetNote.name.displayName : nil,
                    onTap: (touchMode && !reveal) ? { viewModel.submitTouch($0) } : nil,
                    wrongPosition: reveal ? nil : viewModel.lastWrongPosition,
                    minHeight: fretboardHeight
                )
            case .nameNote:
                Text(reveal ? prompt.targetNote.name.displayName : "Name this note")
                    .font(.system(size: compact ? 26 : 40, weight: .bold))
                FretboardView(
                    highlightedPosition: position(for: prompt),
                    revealLabel: reveal ? prompt.targetNote.name.displayName : nil,
                    minHeight: fretboardHeight
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
