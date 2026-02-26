//
//  DebouncedPitchDetector.swift
//  audio_listen
//
//  Decorator: wraps any PitchDetectorProtocol, only emits when same note stable for ~150ms.
//

import Combine
import Foundation

/// Decorator that debounces pitch detection: only emits when the same note is stable for a duration.
final class DebouncedPitchDetector: PitchDetectorProtocol {
    private let wrapped: PitchDetectorProtocol
    private let stabilityDuration: TimeInterval
    private let scheduler: DispatchQueue
    
    private let pitchSubject = PassthroughSubject<DetectedPitch, Never>()
    var currentPitch: AnyPublisher<DetectedPitch, Never> {
        pitchSubject.eraseToAnyPublisher()
    }
    
    init(wrapping wrapped: PitchDetectorProtocol, stabilityDuration: TimeInterval = 0.15, scheduler: DispatchQueue = .main) {
        self.wrapped = wrapped
        self.stabilityDuration = stabilityDuration
        self.scheduler = scheduler
    }
    
    func start() throws {
        wrapped.currentPitch
            .receive(on: scheduler)
            .sink { [weak self] pitch in
                self?.handlePitch(pitch)
            }
            .store(in: &cancellables)
        try wrapped.start()
    }
    
    func stop() {
        wrapped.stop()
        cancellables.removeAll()
        lastNote = nil
        lastNoteTime = nil
        pendingWorkItem?.cancel()
        pendingWorkItem = nil
    }
    
    private var cancellables = Set<AnyCancellable>()
    private var lastNote: Note?
    private var lastNoteTime: Date?
    private var pendingWorkItem: DispatchWorkItem?
    
    private func handlePitch(_ pitch: DetectedPitch) {
        let now = Date()
        
        if lastNote == pitch.note {
            if let start = lastNoteTime {
                if now.timeIntervalSince(start) >= stabilityDuration {
                    pitchSubject.send(pitch)
                    lastNote = nil
                    lastNoteTime = nil
                    pendingWorkItem?.cancel()
                    pendingWorkItem = nil
                }
            }
        } else {
            lastNote = pitch.note
            lastNoteTime = now
            pendingWorkItem?.cancel()
            pendingWorkItem = nil
        }
    }
}
