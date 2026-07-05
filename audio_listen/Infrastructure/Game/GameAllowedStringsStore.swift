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

    static func userDefaultsKey(for instrument: Instrument) -> String {
        "audio_listen_allowed_strings.\(instrument.id)"
    }

    /// Missing key, decode failure, or only out-of-range values → the instrument's default choice.
    /// Successfully stored empty array → empty set (no strings selected).
    func load(for instrument: Instrument) -> Set<Int> {
        let key = Self.userDefaultsKey(for: instrument)
        guard let data = defaults.data(forKey: key) else {
            return instrument.defaultStringChoice.strings
        }
        guard let stored = try? JSONDecoder().decode([Int].self, from: data) else {
            return instrument.defaultStringChoice.strings
        }
        let inRange = stored.filter { (1...instrument.stringCount).contains($0) }
        let set = Set(inRange)
        if set.isEmpty {
            return stored.isEmpty ? [] : instrument.defaultStringChoice.strings
        }
        return set
    }

    func save(_ strings: Set<Int>, for instrument: Instrument) {
        let key = Self.userDefaultsKey(for: instrument)
        let sorted = strings.filter { (1...instrument.stringCount).contains($0) }.sorted()
        guard let data = try? JSONEncoder().encode(sorted) else { return }
        defaults.set(data, forKey: key)
    }

    /// Missing key, decode failure, or only out-of-range values → default strings (E and A).
    /// Successfully stored empty array → empty set (no strings selected).
    func load() -> Set<Int> {
        guard let data = defaults.data(forKey: Self.userDefaultsKey) else {
            return StringSetPresets.defaultStrings
        }
        guard let arr = try? JSONDecoder().decode([Int].self, from: data) else {
            return StringSetPresets.defaultStrings
        }
        let inRange = arr.filter { (1...Instruments.guitar.stringCount).contains($0) }
        let set = Set(inRange)
        if set.isEmpty {
            if arr.isEmpty {
                return []
            }
            return StringSetPresets.defaultStrings
        }
        return set
    }

    func save(_ strings: Set<Int>) {
        let sorted = strings.filter { (1...Instruments.guitar.stringCount).contains($0) }.sorted()
        guard let data = try? JSONEncoder().encode(sorted) else { return }
        defaults.set(data, forKey: Self.userDefaultsKey)
    }
}
