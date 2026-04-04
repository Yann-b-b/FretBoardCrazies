//
//  GameSessionMetricsView.swift
//  audio_listen
//
//  Shows average wrong attempts per target note from persisted rounds.
//

import SwiftUI

struct GameSessionMetricsView: View {
    let averages: [Note: Double]

    private var sortedNotes: [Note] {
        averages.keys.sorted { $0.displayName < $1.displayName }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Avg wrong attempts (saved history)")
                .font(.headline)
            if averages.isEmpty {
                Text("No saved rounds yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sortedNotes, id: \.self) { note in
                    HStack {
                        Text(note.displayName)
                        Spacer()
                        Text(String(format: "%.2f", averages[note]!))
                            .monospacedDigit()
                    }
                    .font(.subheadline)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
