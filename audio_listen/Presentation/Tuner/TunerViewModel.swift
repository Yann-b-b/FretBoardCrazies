//
//  TunerViewModel.swift
//  audio_listen
//
//  ViewModel for the standalone tuner view.
//

import Combine
import Foundation

@MainActor
final class TunerViewModel: ObservableObject {
    @Published private(set) var currentNote: String = "—"
    @Published private(set) var frequency: Double = 0
    @Published private(set) var amplitude: Float = 0
    @Published private(set) var isListening = false
    @Published var errorMessage: String?
    
    private let pitchDetector: PitchDetectorProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(pitchDetector: PitchDetectorProtocol) {
        self.pitchDetector = pitchDetector
    }
    
    func startListening() {
        guard !isListening else { return }
        errorMessage = nil
        do {
            pitchDetector.currentPitch
                .receive(on: DispatchQueue.main)
                .sink { [weak self] pitch in
                    self?.currentNote = pitch.note.displayName
                    self?.frequency = pitch.frequency
                    self?.amplitude = pitch.amplitude
                }
                .store(in: &cancellables)
            try pitchDetector.start()
            isListening = true
        } catch {
            errorMessage = "Could not start microphone: \(error.localizedDescription)"
        }
    }
    
    func stopListening() {
        guard isListening else { return }
        pitchDetector.stop()
        cancellables.removeAll()
        isListening = false
        currentNote = "—"
        frequency = 0
        amplitude = 0
    }
}
