//
//  UserDefaultsAllowedStringsProvider.swift
//  audio_listen
//
//  Bridges `GameAllowedStringsStore` to `AllowedStringsProviding` for one instrument.
//

import Foundation

struct UserDefaultsAllowedStringsProvider: AllowedStringsProviding {
    private let store: GameAllowedStringsStore
    private let instrument: Instrument

    init(store: GameAllowedStringsStore, instrument: Instrument) {
        self.store = store
        self.instrument = instrument
    }

    var allowedStrings: Set<Int> {
        store.load(for: instrument)
    }
}
