import Foundation

@MainActor
final class AutoAdvance: ObservableObject {
    static let minPace: TimeInterval = 1.0
    static let maxPace: TimeInterval = 6.0

    @Published var isPlaying: Bool = false
    @Published var pace: TimeInterval {
        didSet {
            let clamped = min(max(pace, Self.minPace), Self.maxPace)
            if clamped != pace { pace = clamped }
        }
    }

    init(pace: TimeInterval = 2.0) {
        self.pace = min(max(pace, Self.minPace), Self.maxPace)
    }
}
