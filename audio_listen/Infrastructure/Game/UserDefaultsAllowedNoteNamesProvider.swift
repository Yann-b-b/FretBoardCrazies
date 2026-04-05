//
//  UserDefaultsAllowedNoteNamesProvider.swift
//  audio_listen
//
//  Bridges `GameAllowedNoteNamesStore` to `AllowedNoteNamesProviding`.
//

import Foundation

struct UserDefaultsAllowedNoteNamesProvider: AllowedNoteNamesProviding {
    private let store: GameAllowedNoteNamesStore

    init(store: GameAllowedNoteNamesStore) {
        self.store = store
    }

    var allowedNoteNames: Set<NoteName> {
        store.load()
    }
}
