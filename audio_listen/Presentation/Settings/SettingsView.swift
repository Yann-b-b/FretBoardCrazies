//
//  SettingsView.swift
//  audio_listen
//
//  Settings for amplitude threshold, countdown, timeout.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("countdownEnabled") private var countdownEnabled = false
    @AppStorage("timeoutSeconds") private var timeoutSeconds = 5.0
    @AppStorage("minAmplitude") private var minAmplitude = 0.01
    
    var body: some View {
        Form {
            Section("Game") {
                Toggle("Countdown (3-2-1)", isOn: $countdownEnabled)
                Stepper(value: $timeoutSeconds, in: 3...10, step: 1) {
                    Text("Timeout: \(Int(timeoutSeconds)) seconds")
                }
            }
            Section("Audio") {
                Text("Amplitude threshold: \(String(format: "%.3f", minAmplitude))")
                Slider(value: $minAmplitude, in: 0.001...0.1, step: 0.005)
            }
        }
        .navigationTitle("Settings")
    }
}
