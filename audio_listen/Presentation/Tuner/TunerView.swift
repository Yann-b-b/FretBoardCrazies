//
//  TunerView.swift
//  audio_listen
//
//  Standalone tuner to validate pitch detection with real guitar.
//

import SwiftUI

struct TunerView: View {
    @StateObject private var viewModel: TunerViewModel
    
    init(viewModel: TunerViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Guitar Tuner")
                .font(.title)
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            
            Text(viewModel.currentNote)
                .font(.system(size: 72, weight: .bold))
                .monospacedDigit()
            
            Text(String(format: "%.1f Hz", viewModel.frequency))
                .font(.title2)
                .foregroundStyle(.secondary)
            
            Text(String(format: "Amplitude: %.3f", viewModel.amplitude))
                .font(.caption)
                .foregroundStyle(.tertiary)
            
            Spacer()
            
            Button(viewModel.isListening ? "Stop" : "Start") {
                if viewModel.isListening {
                    viewModel.stopListening()
                } else {
                    viewModel.startListening()
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.bottom, 32)
        }
        .padding()
        .onDisappear {
            viewModel.stopListening()
        }
    }
}
