//
//  SettingsView.swift
//  audio_listen
//
//  Game settings.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("countdownEnabled") private var countdownEnabled = false
    @AppStorage(GameSettingsKeys.limitFretsToTwelve) private var limitFretsToTwelve = true

    var body: some View {
        Form {
            Section("Game") {
                Toggle("Countdown (3-2-1)", isOn: $countdownEnabled)
                Toggle("Limit targets to frets 0–11", isOn: $limitFretsToTwelve)
            }
        }
        .navigationTitle("Settings")
    }
}
