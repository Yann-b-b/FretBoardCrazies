import Foundation

struct ProgressionSelectionStore {
    private enum Key {
        static let progression = "audio_listen_chord_progression_id"
        static let tonic = "audio_listen_chord_tonic"
        static let rootString = "audio_listen_chord_root_string"
        static let displayMode = "audio_listen_chord_display_mode"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var progression: Progression {
        let id = defaults.string(forKey: Key.progression)
        return Progressions.all.first { $0.id == id } ?? Progressions.byId("major-ii-v-i")!
    }

    var tonic: NoteName {
        guard defaults.object(forKey: Key.tonic) != nil,
              let name = NoteName(rawValue: defaults.integer(forKey: Key.tonic)) else { return .c }
        return name
    }

    var rootString: RootString {
        guard let raw = defaults.string(forKey: Key.rootString),
              let value = RootString(rawValue: raw) else { return .e6 }
        return value
    }

    var displayMode: ProgressionSession.DisplayMode {
        defaults.bool(forKey: Key.displayMode) ? .nameOnly : .nameAndFingering
    }

    func save(progressionId: String, tonic: NoteName, rootString: RootString, displayMode: ProgressionSession.DisplayMode) {
        defaults.set(progressionId, forKey: Key.progression)
        defaults.set(tonic.rawValue, forKey: Key.tonic)
        defaults.set(rootString.rawValue, forKey: Key.rootString)
        defaults.set(displayMode == .nameOnly, forKey: Key.displayMode)
    }
}
