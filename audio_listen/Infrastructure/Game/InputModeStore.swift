import Foundation

struct InputModeStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save(_ mode: InputMode) {
        defaults.set(mode == .tapping, forKey: GameSettingsKeys.touchMode)
    }
}
