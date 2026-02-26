//
//  GameViewModel.swift
//  audio_listen
//
//  ViewModel for the main game: coordinates state machine, pitch detection, and use cases.
//

import Combine
import Foundation

@MainActor
final class GameViewModel: ObservableObject {
    @Published private(set) var state: GameState = .idle
    @Published private(set) var detectedNote: String = "—"
    @Published var errorMessage: String?
    
    private let pitchDetector: PitchDetectorProtocol
    private let generateNoteUseCase: GenerateTargetNoteUseCase
    private let validateNoteUseCase: ValidateNoteUseCase
    private let stateMachine: GameStateMachine
    private let scoreRepository: ScoreRepositoryProtocol
    
    private var cancellables = Set<AnyCancellable>()
    private let timeoutSeconds: TimeInterval
    private let countdownEnabled: Bool
    private var timeoutTimer: Timer?
    private var countdownTimer: Timer?
    
    init(
        pitchDetector: PitchDetectorProtocol,
        generateNoteUseCase: GenerateTargetNoteUseCase,
        validateNoteUseCase: ValidateNoteUseCase,
        stateMachine: GameStateMachine,
        scoreRepository: ScoreRepositoryProtocol,
        timeoutSeconds: TimeInterval = 5,
        countdownEnabled: Bool = true
    ) {
        self.pitchDetector = pitchDetector
        self.generateNoteUseCase = generateNoteUseCase
        self.validateNoteUseCase = validateNoteUseCase
        self.stateMachine = stateMachine
        self.scoreRepository = scoreRepository
        self.timeoutSeconds = timeoutSeconds
        self.countdownEnabled = countdownEnabled
        
        stateMachine.setCallbacks(GameStateMachineCallbacks(
            onPlayingStarted: { [weak self] in
                Task { @MainActor in self?.startTimeoutTimer() }
            },
            onSuccess: { [weak self] time in
                Task { @MainActor in self?.handleSuccess(time: time) }
            },
            onTimeout: { [weak self] in
                Task { @MainActor in self?.handleTimeout() }
            }
        ))
    }
    
    func startRound() {
        errorMessage = nil
        let (note, position) = generateNoteUseCase.execute()
        if stateMachine.transition(to: .ready(targetNote: note, targetPosition: position)) {
            state = stateMachine.state
        }
    }
    
    func beginRound() {
        guard case .ready(let targetNote, let targetPosition) = state else { return }
        if countdownEnabled {
            startCountdown()
        } else {
            goToPlaying()
        }
    }
    
    private func goToPlaying() {
        let targetNote: Note?
        let targetPosition: FretPosition?
        switch state {
        case .ready(let note, let pos): targetNote = note; targetPosition = pos
        case .countdown(_, let note, let pos): targetNote = note; targetPosition = pos
        default: targetNote = nil; targetPosition = nil
        }
        guard let note = targetNote, let pos = targetPosition else { return }
        
        if stateMachine.transition(to: .playing(startTime: Date(), targetNote: note, targetPosition: pos)) {
            state = stateMachine.state
            startPitchListening()
        }
    }
    
    func startCountdown() {
        guard case .ready(let targetNote, let targetPosition) = state else { return }
        stateMachine.transition(to: .countdown(remaining: 3, targetNote: targetNote, targetPosition: targetPosition))
        state = stateMachine.state
        
        var remaining = 3
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            Task { @MainActor in
                remaining -= 1
                if remaining > 0 {
                    self?.stateMachine.transition(to: .countdown(remaining: remaining, targetNote: targetNote, targetPosition: targetPosition))
                    self?.state = self?.stateMachine.state ?? .idle
                } else {
                    timer.invalidate()
                    self?.countdownTimer = nil
                    self?.goToPlaying()
                }
            }
        }
        RunLoop.main.add(countdownTimer!, forMode: .common)
    }
    
    func nextRound() {
        stopPitchListening()
        cancelTimers()
        stateMachine.transition(to: .idle)
        state = stateMachine.state
        startRound()
    }
    
    private func startPitchListening() {
        do {
            pitchDetector.currentPitch
                .receive(on: DispatchQueue.main)
                .sink { [weak self] pitch in
                    self?.handleDetectedPitch(pitch)
                }
                .store(in: &cancellables)
            try pitchDetector.start()
            detectedNote = "—"
        } catch {
            errorMessage = "Could not start microphone: \(error.localizedDescription)"
        }
    }
    
    private func stopPitchListening() {
        pitchDetector.stop()
        cancellables.removeAll()
    }
    
    private func handleDetectedPitch(_ pitch: DetectedPitch) {
        detectedNote = pitch.note.displayName
        
        guard case .playing(let startTime, let targetNote, let targetPosition) = state else { return }
        
        if validateNoteUseCase.execute(detected: pitch.note, target: targetNote) {
            cancelTimers()
            stopPitchListening()
            let reactionTime = Date().timeIntervalSince(startTime)
            stateMachine.transition(to: .success(time: reactionTime, targetNote: targetNote, targetPosition: targetPosition))
            state = stateMachine.state
        }
    }
    
    private func startTimeoutTimer() {
        timeoutTimer?.invalidate()
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeoutSeconds, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.handleTimeout()
            }
        }
        RunLoop.main.add(timeoutTimer!, forMode: .common)
    }
    
    private func handleSuccess(time: TimeInterval) {
        guard case .success(_, let targetNote, let targetPosition) = state else { return }
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
        scoreRepository.save(round: GameRound(
            targetNote: targetNote,
            targetPosition: targetPosition,
            wasCorrect: true,
            reactionTime: time
        ))
    }
    
    private func handleTimeout() {
        guard case .playing(_, let targetNote, let targetPosition) = state else { return }
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
        #endif
        cancelTimers()
        stopPitchListening()
        stateMachine.transition(to: .timeout(targetNote: targetNote, targetPosition: targetPosition))
        state = stateMachine.state
        scoreRepository.save(round: GameRound(
            targetNote: targetNote,
            targetPosition: targetPosition,
            wasCorrect: false,
            reactionTime: nil
        ))
    }
    
    private func cancelTimers() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
}
