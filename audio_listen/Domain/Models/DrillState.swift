import Foundation

enum DrillState: Equatable {
    case idle
    case countdown(remaining: Int, prompt: DrillPrompt)
    case playing(startTime: Date, prompt: DrillPrompt)
    case success(reactionTime: TimeInterval, prompt: DrillPrompt)
}
