//
//  GameAllowedNoteNamesStore.swift
//  audio_listen
//
//  Persists selected note names (NoteName rawValue 0...11) as JSON array in UserDefaults.
//

import Foundation

/// Loads and saves the set of note names allowed for note-name practice targets.
struct GameAllowedNoteNamesStore {
    static let userDefaultsKey = "audio_listen_game_allowed_note_names"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Missing key or invalid decode → all 12 names. Empty stored array → empty set.
    func load() -> Set<NoteName> {
        guard let data = defaults.data(forKey: Self.userDefaultsKey) else {
            return Set(NoteName.allCases)
        }
        guard let arr = try? JSONDecoder().decode([Int].self, from: data) else {
            return Set(NoteName.allCases)
        }
        let mapped = arr.compactMap { NoteName(rawValue: $0) }
        let set = Set(mapped)
        if set.isEmpty {
            if arr.isEmpty {
                return []
            }
            return Set(NoteName.allCases)
        }
        return set
    }

    func save(_ names: Set<NoteName>) {
        let sorted = names.map(\.rawValue).sorted()
        guard let data = try? JSONEncoder().encode(sorted) else { return }
        defaults.set(data, forKey: Self.userDefaultsKey)
    }
}
