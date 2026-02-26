//
//  AudioKitPitchAdapter.swift
//  audio_listen
//
//  Adapter: conforms to PitchDetectorProtocol using AudioInputFacade + NoteConverter.
//

import Combine
import Foundation

/// Adapter that conforms to PitchDetectorProtocol using the audio facade and note converter.
final class AudioKitPitchAdapter: PitchDetectorProtocol {
    private let facade: AudioInputFacade
    private let minAmplitude: Float
    private var isRunning = false
    
    private let pitchSubject = PassthroughSubject<DetectedPitch, Never>()
    var currentPitch: AnyPublisher<DetectedPitch, Never> {
        pitchSubject.eraseToAnyPublisher()
    }
    
    init(facade: AudioInputFacade = AudioInputFacade(), minAmplitude: Float = 0.01) {
        self.facade = facade
        self.minAmplitude = minAmplitude
    }
    
    func start() throws {
        guard !isRunning else { return }
        facade.rawPitchStream
            .receive(on: DispatchQueue.main)
            .sink { [weak self] raw in
                self?.handleRawPitch(raw)
            }
            .store(in: &cancellables)
        try facade.start()
        isRunning = true
    }
    
    func stop() {
        guard isRunning else { return }
        facade.stop()
        cancellables.removeAll()
        isRunning = false
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private func handleRawPitch(_ raw: RawPitchData) {
        switch NoteConverter.frequencyToNote(raw.frequency, amplitude: raw.amplitude, minAmplitude: minAmplitude) {
        case .success(let note):
            pitchSubject.send(DetectedPitch(note: note, frequency: raw.frequency, amplitude: raw.amplitude))
        case .failure:
            break
        }
    }
}
