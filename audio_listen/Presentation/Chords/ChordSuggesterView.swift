import SwiftUI

struct ChordSuggesterView: View {
    @StateObject private var session: ChordSuggesterSession
    @StateObject private var auto = AutoAdvance()
    private let instrument: Instrument

    init(session: ChordSuggesterSession, instrument: Instrument = Instruments.guitar) {
        _session = StateObject(wrappedValue: session)
        self.instrument = instrument
    }

    private func placed(_ chord: ChordSymbol) -> PlacedChord? {
        guard let voicing = Voicings.voicing(qualityId: chord.qualityId, rootString: .e6) else { return nil }
        let pitchClass = ChordNaming.rootName(tonic: session.tonic, degree: chord.degree).semitonesFromC
        return ChordPlacement.place(voicing: voicing, rootPitchClass: pitchClass, instrument: instrument)
    }

    private func name(_ chord: ChordSymbol) -> String {
        ChordNaming.rootName(tonic: session.tonic, degree: chord.degree).displayName
            + (ChordQualities.byId(chord.qualityId)?.symbol ?? chord.qualityId)
    }

    var body: some View {
        VStack(spacing: 16) {
            selectors
            header
            if let current = placed(session.current) {
                ChordFretboardView(placedChord: current, showFingering: session.revealed)
                    .padding(.horizontal)
            }
            transport
        }
        .padding(.vertical)
        .task(id: TimerKey(playing: auto.isPlaying, pace: auto.pace, step: session.step)) {
            guard auto.isPlaying else { return }
            try? await Task.sleep(nanoseconds: UInt64(auto.pace * 1_000_000_000))
            if !Task.isCancelled { session.advance() }
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text(name(session.current))
                .font(.system(size: 40, weight: .bold, design: .serif))
                .contentTransition(.numericText())
            if let ruleId = session.lastRuleId {
                Text(Explanations.text(for: ruleId).short)
                    .font(.subheadline)
                    .foregroundStyle(Color.orange)
            } else {
                Text("tonic — press play")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let upcoming = session.upcoming {
                Text("next: \(name(upcoming))")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var transport: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    auto.isPlaying = false
                    session.resetToTonic()
                } label: {
                    Image(systemName: "arrow.counterclockwise").font(.headline)
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
                    session.advance()
                } label: {
                    Text("Next ›").font(.headline)
                        .padding(.vertical, 12).padding(.horizontal, 18)
                }
                .buttonStyle(.bordered)
            }
            HStack(spacing: 10) {
                Text("pace").font(.caption).foregroundStyle(.secondary)
                Slider(value: $auto.pace, in: AutoAdvance.minPace...AutoAdvance.maxPace)
                Text(String(format: "%.1fs", auto.pace)).font(.caption.monospaced()).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }

    private var selectors: some View {
        HStack {
            Menu {
                ForEach(ChordSuggesterSession.minTier...ChordSuggesterSession.maxTier, id: \.self) { level in
                    Button("Tier \(level)") { session.tierLevel = level }
                }
            } label: { Label("Tier \(session.tierLevel)", systemImage: "dial.medium") }

            Spacer()

            Picker("Key", selection: $session.tonic) {
                ForEach(NoteName.allCases, id: \.self) { note in Text(note.displayName).tag(note) }
            }
            .pickerStyle(.menu)

            Button {
                session.revealed.toggle()
            } label: {
                Image(systemName: session.revealed ? "eye" : "eye.slash")
            }
        }
        .padding(.horizontal)
    }
}

private struct TimerKey: Hashable {
    let playing: Bool
    let pace: TimeInterval
    let step: Int
}

#Preview {
    ChordSuggesterView(session: ChordSuggesterSession())
}
