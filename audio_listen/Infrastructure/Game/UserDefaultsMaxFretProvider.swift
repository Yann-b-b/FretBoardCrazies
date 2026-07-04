//
//  UserDefaultsMaxFretProvider.swift
//  audio_listen
//
//  Reads "limit frets to 0–11" from UserDefaults with the same default as Settings when the key is unset.
//

import Foundation

struct UserDefaultsMaxFretProvider: MaxFretProviding {
    private let defaults: UserDefaults
    private let instrument: Instrument

    init(defaults: UserDefaults = .standard, instrument: Instrument = Instruments.guitar) {
        self.defaults = defaults
        self.instrument = instrument
    }

    var maxFretInclusive: Int {
        let limitToTwelve: Bool
        if defaults.object(forKey: GameSettingsKeys.limitFretsToTwelve) == nil {
            limitToTwelve = true
        } else {
            limitToTwelve = defaults.bool(forKey: GameSettingsKeys.limitFretsToTwelve)
        }
        return limitToTwelve ? GameTargetFretBounds.limitedMaxFretInclusive : instrument.fretCount
    }
}
