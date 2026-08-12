import Foundation

@MainActor
final class ProgressionSession: ObservableObject {
    enum DisplayMode {
        case nameAndFingering
        case nameOnly
    }

    @Published var progression: Progression { didSet { reset() } }
    @Published var tonic: NoteName
    @Published var rootString: RootString
    @Published var displayMode: DisplayMode { didSet { revealed = fullyRevealed } }

    @Published private(set) var index: Int = 0
    @Published private(set) var revealed: Bool

    init(progression: Progression,
         tonic: NoteName = .c,
         rootString: RootString = .e6,
         displayMode: DisplayMode = .nameAndFingering) {
        self.progression = progression
        self.tonic = tonic
        self.rootString = rootString
        self.displayMode = displayMode
        self.revealed = displayMode == .nameAndFingering
    }

    var currentStep: ProgressionStep { progression.steps[index] }
    var nextStep: ProgressionStep { progression.steps[(index + 1) % progression.steps.count] }

    private var fullyRevealed: Bool { displayMode == .nameAndFingering }

    func primaryAction() {
        if displayMode == .nameOnly && !revealed {
            revealed = true
        } else {
            advance()
        }
    }

    func advance() {
        index = (index + 1) % progression.steps.count
        revealed = fullyRevealed
    }

    func previous() {
        index = (index - 1 + progression.steps.count) % progression.steps.count
        revealed = fullyRevealed
    }

    private func reset() {
        index = 0
        revealed = fullyRevealed
    }
}
