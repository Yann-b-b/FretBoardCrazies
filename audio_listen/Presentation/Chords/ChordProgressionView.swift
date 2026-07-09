import SwiftUI

struct ChordProgressionView: View {
    @StateObject private var session: ProgressionSession
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
        VStack(spacing: 20) {
            controls

            Text(name(session.currentStep))
                .font(.system(size: 40, weight: .bold, design: .serif))
                .contentTransition(.numericText())

            ChordNeckView(placedChord: placed(session.currentStep), showFingering: session.revealed)
                .padding(.horizontal)

            HStack(spacing: 6) {
                Text("next:").foregroundStyle(.secondary)
                Text(name(session.nextStep)).fontWeight(.semibold)
            }
            .font(.subheadline)

            Spacer()

            HStack(spacing: 12) {
                Button(action: { session.previous() }) {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 20)
                }
                .buttonStyle(.bordered)

                Button(action: { session.primaryAction() }) {
                    Text(primaryLabel)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
        }
        .padding(.top)
        .onChange(of: session.index) { _ in persist() }
    }

    private var primaryLabel: String {
        session.displayMode == .nameOnly && !session.revealed ? "Reveal" : "Next ›"
    }

    private var controls: some View {
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

#Preview {
    ChordProgressionView(
        session: ProgressionSession(progression: Progressions.byId("major-ii-v-i")!),
        instrument: Instruments.guitar,
        store: ProgressionSelectionStore()
    )
}
