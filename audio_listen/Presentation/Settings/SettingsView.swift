//
//  SettingsView.swift
//  audio_listen
//
//  Settings for amplitude threshold, countdown, timeout.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("countdownEnabled") private var countdownEnabled = false
    @AppStorage("minAmplitude") private var minAmplitude = 0.01
    @AppStorage("limitFretsToTwelve") private var limitFretsToTwelve = true

    var body: some View {
        Form {
            Section("Game") {
                Toggle("Countdown (3-2-1)", isOn: $countdownEnabled)
                Toggle("Limit targets to frets 0–12", isOn: $limitFretsToTwelve)
            }
            Section("Audio") {
                Text("Amplitude threshold: \(String(format: "%.3f", minAmplitude))")
                Slider(value: $minAmplitude, in: 0.001...0.1, step: 0.005)
            }
        }
        .navigationTitle("Settings")
    }
}
