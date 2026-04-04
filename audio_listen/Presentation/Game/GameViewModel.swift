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
    
    private var pitchSubscription: AnyCancellable?
    private let countdownEnabled: Bool
    private var countdownTimer: Timer?
    private var autoAdvanceTask: Task<Void, Never>?
    private var engineStarted = false
    
    init(
        pitchDetector: PitchDetectorProtocol,
        generateNoteUseCase: GenerateTargetNoteUseCase,
        validateNoteUseCase: ValidateNoteUseCase,
        stateMachine: GameStateMachine,
        scoreRepository: ScoreRepositoryProtocol,
        countdownEnabled: Bool = true
    ) {
        self.pitchDetector = pitchDetector
        self.generateNoteUseCase = generateNoteUseCase
        self.validateNoteUseCase = validateNoteUseCase
        self.stateMachine = stateMachine
        self.scoreRepository = scoreRepository
        self.countdownEnabled = countdownEnabled
        
        stateMachine.setCallbacks(GameStateMachineCallbacks(
            onSuccess: { [weak self] time in
                Task { @MainActor in self?.handleSuccess(time: time) }
            }
        ))
    }
    
    /// Start the game session. Generates the first note and begins listening.
    func startGame() {
        errorMessage = nil
        let (note, position) = generateNoteUseCase.execute()
        
        if countdownEnabled {
            startCountdown(targetNote: note, targetPosition: position)
        } else {
            beginPlaying(targetNote: note, targetPosition: position)
        }
    }
    
    /// Stop the game session and return to idle.
    func stopGame() {
        autoAdvanceTask?.cancel()
        autoAdvanceTask = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
        stopPitchListening()
        stateMachine.transition(to: .idle)
        state = stateMachine.state
        detectedNote = "—"
    }
    
    private func beginPlaying(targetNote: Note, targetPosition: FretPosition) {
        if stateMachine.transition(to: .playing(startTime: Date(), targetNote: targetNote, targetPosition: targetPosition)) {
            state = stateMachine.state
            startPitchListening()
        }
    }
    
    private func startCountdown(targetNote: Note, targetPosition: FretPosition) {
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
                    self?.beginPlaying(targetNote: targetNote, targetPosition: targetPosition)
                }
            }
        }
        RunLoop.main.add(countdownTimer!, forMode: .common)
    }
    
    private func advanceToNextNote() {
        let (note, position) = generateNoteUseCase.execute()
        stateMachine.transition(to: .playing(startTime: Date(), targetNote: note, targetPosition: position))
        state = stateMachine.state
        startPitchListening()
    }
    
    private func startPitchListening() {
        do {
            if !engineStarted {
                try pitchDetector.start()
                engineStarted = true
            }
            pitchSubscription = pitchDetector.currentPitch
                .receive(on: DispatchQueue.main)
                .sink { [weak self] pitch in
                    self?.handleDetectedPitch(pitch)
                }
            detectedNote = "—"
        } catch {
            errorMessage = "Could not start microphone: \(error.localizedDescription)"
        }
    }
    
    private func stopPitchListening() {
        pitchSubscription?.cancel()
        pitchSubscription = nil
    }
    
    private func handleDetectedPitch(_ pitch: DetectedPitch) {
        detectedNote = pitch.note.displayName
        
        guard case .playing(let startTime, let targetNote, let targetPosition) = state else { return }
        
        if validateNoteUseCase.execute(detected: pitch.note, target: targetNote) {
            stopPitchListening()
            let reactionTime = Date().timeIntervalSince(startTime)
            stateMachine.transition(to: .success(time: reactionTime, targetNote: targetNote, targetPosition: targetPosition))
            state = stateMachine.state
        }
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
            reactionTime: time,
            playedAt: Date()
        ))
        
        // Auto-advance to next note after a brief pause
        autoAdvanceTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            advanceToNextNote()
        }
    }
}
