//
//  UserDefaultsAllowedStringsProvider.swift
//  audio_listen
//
//  Bridges `GameAllowedStringsStore` to `AllowedStringsProviding`.
//

import Foundation

struct UserDefaultsAllowedStringsProvider: AllowedStringsProviding {
    private let store: GameAllowedStringsStore

    init(store: GameAllowedStringsStore) {
        self.store = store
    }

    var allowedStrings: Set<Int> {
        store.load()
    }
}
