import SwiftUI

struct ChordProgressionView: View {
    @StateObject private var session: ProgressionSession
    @StateObject private var auto = AutoAdvance()
    private let instrument: Instrument
    private let store: ProgressionSelectionStore

    init(session: ProgressionSession, instrument: Instrument, store: ProgressionSelectionStore) {
        _session = StateObject(wrappedValue: session)
        self.instrument = instrument
        self.store = store
    }

    private func placed(_ step: ProgressionStep) -> PlacedChord {
        let voicing = Voicings.voicing(qualityId: step.qualityId, rootString: session.rootString)!
        let pitchClass = ChordNaming.rootName(tonic: session.tonic, degree: step.degree).semitonesFromC
        return ChordPlacement.place(voicing: voicing, rootPitchClass: pitchClass, instrument: instrument)
    }

    private func name(_ step: ProgressionStep) -> String {
        ChordNaming.displayName(step: step, tonic: session.tonic)
    }

    var body: some View {
        let current = placed(session.currentStep)
        VStack(spacing: 16) {
            selectors
            VStack(spacing: 4) {
                Text(name(session.currentStep))
                    .font(.system(size: 40, weight: .bold, design: .serif))
                    .contentTransition(.numericText())
                HStack(spacing: 8) {
                    Text("\(current.rootFret)fr").foregroundStyle(Color.orange)
                    Text("·").foregroundStyle(.secondary)
                    Text("next: \(name(session.nextStep))").foregroundStyle(.secondary)
                }
                .font(.subheadline.monospaced())
            }
            ChordFretboardView(placedChord: current, showFingering: session.revealed)
                .padding(.horizontal)
            transport
        }
        .padding(.vertical)
        .onChange(of: session.index) { _ in persist() }
        .task(id: TimerKey(playing: auto.isPlaying, pace: auto.pace, index: session.index)) {
            guard auto.isPlaying else { return }
            try? await Task.sleep(nanoseconds: UInt64(auto.pace * 1_000_000_000))
            if !Task.isCancelled { session.advance() }
        }
    }

    private var transport: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    auto.isPlaying = false
                    session.previous()
                } label: {
                    Image(systemName: "chevron.left").font(.headline)
                        .padding(.vertical, 12).padding(.horizontal, 18)
                }
                .buttonStyle(.bordered)

                Button { auto.isPlaying.toggle() } label: {
                    Image(systemName: auto.isPlaying ? "pause.fill" : "play.fill")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    auto.isPlaying = false
                    session.primaryAction()
                } label: {
                    Text(primaryLabel).font(.headline)
                        .padding(.vertical, 12).padding(.horizontal, 18)
                }
                .buttonStyle(.bordered)
            }
            HStack(spacing: 10) {
                Text("pace").font(.caption).foregroundStyle(.secondary)
                Slider(value: Binding(get: { auto.pace }, set: { auto.pace = $0 }),
                       in: AutoAdvance.minPace...AutoAdvance.maxPace)
                Text(String(format: "%.1fs", auto.pace)).font(.caption.monospaced()).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }

    private var primaryLabel: String {
        session.displayMode == .nameOnly && !session.revealed ? "Reveal" : "Next ›"
    }

    private var selectors: some View {
        HStack {
            Menu {
                ForEach(Progressions.all, id: \.id) { progression in
                    Button(progression.name) { session.progression = progression; persist() }
                }
            } label: { Label(session.progression.name, systemImage: "music.note.list") }

            Spacer()

            Picker("Key", selection: Binding(get: { session.tonic }, set: { session.tonic = $0; persist() })) {
                ForEach(NoteName.allCases, id: \.self) { note in Text(note.displayName).tag(note) }
            }
            .pickerStyle(.menu)

            Button {
                session.displayMode = session.displayMode == .nameAndFingering ? .nameOnly : .nameAndFingering
                persist()
            } label: {
                Image(systemName: session.displayMode == .nameOnly ? "eye.slash" : "eye")
            }
        }
        .padding(.horizontal)
    }

    private func persist() {
        store.save(progressionId: session.progression.id, tonic: session.tonic,
                   rootString: session.rootString, displayMode: session.displayMode)
    }
}

private struct TimerKey: Hashable {
    let playing: Bool
    let pace: TimeInterval
    let index: Int
}

#Preview {
    ChordProgressionView(
        session: ProgressionSession(progression: Progressions.byId("major-ii-v-i")!),
        instrument: Instruments.guitar,
        store: ProgressionSelectionStore()
    )
}
