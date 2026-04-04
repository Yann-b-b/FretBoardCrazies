//
//  GameAllowedStringsStore.swift
//  audio_listen
//
//  Persists selected practice strings (1...6) in UserDefaults as JSON array.
//

import Foundation

/// Loads and saves the set of guitar strings allowed for game targets.
struct GameAllowedStringsStore {
    static let userDefaultsKey = "audio_listen_game_allowed_strings"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Missing key, decode failure, or only out-of-range values → all strings.
    /// Successfully stored empty array → empty set (no strings selected).
    func load() -> Set<Int> {
        guard let data = defaults.data(forKey: Self.userDefaultsKey) else {
            return Set(1...6)
        }
        guard let arr = try? JSONDecoder().decode([Int].self, from: data) else {
            return Set(1...6)
        }
        let inRange = arr.filter { (1...6).contains($0) }
        let set = Set(inRange)
        if set.isEmpty {
            if arr.isEmpty {
                return []
            }
            return Set(1...6)
        }
        return set
    }

    func save(_ strings: Set<Int>) {
        let sorted = strings.filter { (1...6).contains($0) }.sorted()
        guard let data = try? JSONEncoder().encode(sorted) else { return }
        defaults.set(data, forKey: Self.userDefaultsKey)
    }
}
