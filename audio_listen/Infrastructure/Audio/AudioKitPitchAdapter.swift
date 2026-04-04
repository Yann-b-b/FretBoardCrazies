//
//  AudioKitPitchAdapter.swift
//  audio_listen
//
//  Pitch via SoundpipeAudioKit PitchTap + NoteConverter.
//

import AudioKit
import Combine
import Foundation
import SoundpipeAudioKit

enum PitchEngineError: Error, LocalizedError {
    case noMicrophoneInput

    var errorDescription: String? {
        switch self {
        case .noMicrophoneInput:
            return "No microphone input is available."
        }
    }
}

/// Adapter that runs an `AudioEngine` with `PitchTap` on the mic and emits `DetectedPitch` values.
final class AudioKitPitchAdapter: PitchDetectorProtocol {
    private let engine = AudioEngine()
    private var pitchTap: PitchTap?

    private let pitchSubject = PassthroughSubject<DetectedPitch, Never>()
    var currentPitch: AnyPublisher<DetectedPitch, Never> {
        pitchSubject.eraseToAnyPublisher()
    }

    private var isRunning = false

    init() {}

    func start() throws {
        guard !isRunning else { return }

        #if os(iOS)
        try Settings.setSession(category: .playAndRecord, with: [.defaultToSpeaker, .allowBluetooth])
        #endif

        guard let input = engine.input else {
            throw PitchEngineError.noMicrophoneInput
        }

        let mixer = Mixer(input)
        mixer.volume = 0
        engine.output = mixer

        pitchTap = PitchTap(input) { [weak self] pitches, amplitudes in
            self?.handleTap(pitches: pitches, amplitudes: amplitudes)
        }
        pitchTap?.start()
        do {
            try engine.start()
        } catch {
            pitchTap?.stop()
            pitchTap = nil
            throw error
        }
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        pitchTap?.stop()
        pitchTap = nil
        engine.stop()
        isRunning = false
    }

    private func handleTap(pitches: [Float], amplitudes: [Float]) {
        guard let frequency = pitches.first.map(Double.init), frequency > 0 else { return }
        let amplitude: Float = amplitudes.first ?? 0
        let minAmplitude = Self.minAmplitudeThreshold
        switch NoteConverter.frequencyToNote(frequency, amplitude: amplitude, minAmplitude: minAmplitude) {
        case .success(let note):
            pitchSubject.send(DetectedPitch(note: note, frequency: frequency, amplitude: amplitude))
        case .failure:
            break
        }
    }

    private static let minAmplitudeThreshold: Float = 0.01
}
