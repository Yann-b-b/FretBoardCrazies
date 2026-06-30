//
//  SettingsView.swift
//  audio_listen
//
//  Game settings.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage(GameSettingsKeys.countdownEnabled) private var countdownEnabled = false
    @AppStorage(GameSettingsKeys.limitFretsToTwelve) private var limitFretsToTwelve = true

    var body: some View {
        Form {
            Section("Game") {
                Toggle("Countdown (3-2-1)", isOn: $countdownEnabled)
                Toggle("Limit targets to frets 0–11", isOn: $limitFretsToTwelve)
            }
        }
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Image("bg-settings")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        )
        .navigationTitle("Settings")
    }
}
