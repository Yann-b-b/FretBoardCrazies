import Charts
import SwiftUI

struct TrendView: View {
    let history: [DailyRecord]

    enum Metric: String, CaseIterable, Identifiable {
        case reps = "Reps"
        case mastered = "Mastered"
        case reaction = "Avg s"
        var id: String { rawValue }
    }

    @State private var metric: Metric = .reps

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trend").font(.headline)
            Picker("Metric", selection: $metric) {
                ForEach(Metric.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            if history.count < 2 {
                Text("Play on more days to see your trend.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 140)
            } else {
                Chart(history, id: \.dayStart) { record in
                    LineMark(
                        x: .value("Day", record.dayStart),
                        y: .value(metric.rawValue, value(for: record))
                    )
                    .symbol(.circle)
                }
                .frame(minHeight: 160)
            }
        }
    }

    private func value(for record: DailyRecord) -> Double {
        switch metric {
        case .reps: return Double(record.reps)
        case .mastered: return Double(record.masteredSnapshot)
        case .reaction: return record.averageReaction
        }
    }
}
