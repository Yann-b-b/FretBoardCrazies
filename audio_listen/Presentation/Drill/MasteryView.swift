import SwiftUI

struct MasteryView: View {
    private let progressRepository: DrillProgressRepositoryProtocol
    private let masteredBox: Int

    @State private var heatmap: [DrillItemKey: MasteryLevel] = [:]
    @State private var totals: (unseen: Int, learning: Int, mastered: Int) = (0, 0, 0)

    init(progressRepository: DrillProgressRepositoryProtocol, masteredBox: Int = 4) {
        self.progressRepository = progressRepository
        self.masteredBox = masteredBox
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Progress").font(.title2).bold()
            FretboardView(heatmap: heatmap)
            HStack(spacing: 24) {
                legend(color: .gray, label: "Unseen \(totals.unseen)")
                legend(color: .orange, label: "Learning \(totals.learning)")
                legend(color: .green, label: "Mastered \(totals.mastered)")
            }
        }
        .padding(24)
        .frame(minWidth: 640, minHeight: 420)
        .onAppear(perform: reload)
    }

    private func legend(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 12, height: 12)
            Text(label)
        }
    }

    private func reload() {
        let stats = progressRepository.loadAll()
        var map: [DrillItemKey: MasteryLevel] = [:]
        var u = 0, l = 0, m = 0
        for (key, s) in stats {
            let level = MasteryLevel.from(box: s.box, attempts: s.attempts, masteredBox: masteredBox)
            map[key] = level
            switch level {
            case .unseen: u += 1
            case .learning: l += 1
            case .mastered: m += 1
            }
        }
        heatmap = map
        totals = (u, l, m)
    }
}
