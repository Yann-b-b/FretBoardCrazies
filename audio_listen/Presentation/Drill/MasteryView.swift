import SwiftUI

struct MasteryView: View {
    private let progressRepository: DrillProgressRepositoryProtocol
    private let dailyHistoryStore: DailyHistoryStore
    private let masteredBox: Int

    @State private var heatmap: [DrillItemKey: MasteryLevel] = [:]
    @State private var totals: (unseen: Int, learning: Int, mastered: Int) = (0, 0, 0)
    @State private var beltRank: BeltRank = BeltRank.from(stats: [:], maxBox: DrillTuning.maxBox, universeSize: DrillTuning.totalItemCount)
    @State private var history: [DailyRecord] = []

    init(progressRepository: DrillProgressRepositoryProtocol, dailyHistoryStore: DailyHistoryStore, masteredBox: Int = DrillTuning.maxBox) {
        self.progressRepository = progressRepository
        self.dailyHistoryStore = dailyHistoryStore
        self.masteredBox = masteredBox
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Progress").font(.title2).bold()
                beltCard
                FretboardView(heatmap: heatmap)
                HStack(spacing: 24) {
                    legend(color: .gray, label: "Unseen \(totals.unseen)")
                    legend(color: .orange, label: "Learning \(totals.learning)")
                    legend(color: .green, label: "Mastered \(totals.mastered)")
                }
                TrendView(history: history)
            }
            .padding(24)
            .frame(minWidth: 640)
        }
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Image("bg-progress")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        )
        .onAppear(perform: reload)
    }

    private var beltCard: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(beltRank.belt.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 32)
                Text("\(beltRank.belt.displayName) belt").font(.headline)
            }
            ProgressView(value: beltRank.belt == .black ? 1.0 : beltRank.fractionToNext)
                .frame(maxWidth: 280)
            Text(beltRank.belt == .black ? "Max rank" : "Progress to next belt")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func legend(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 12, height: 12)
            Text(label)
        }
    }

    private func reload() {
        let stats = progressRepository.loadAll()
        let universe = SelectNextPromptUseCase().candidates(
            allowedStrings: Set(1...6),
            allowedNoteNames: Set(NoteName.allCases),
            maxFretInclusive: 11
        )
        var map: [DrillItemKey: MasteryLevel] = [:]
        var u = 0, l = 0, m = 0
        for key in universe {
            let s = stats[key]
            let level = MasteryLevel.from(box: s?.box ?? 0, attempts: s?.attempts ?? 0, masteredBox: masteredBox)
            map[key] = level
            switch level {
            case .unseen: u += 1
            case .learning: l += 1
            case .mastered: m += 1
            }
        }
        heatmap = map
        totals = (u, l, m)
        beltRank = BeltRank.from(stats: stats, maxBox: masteredBox, universeSize: DrillTuning.totalItemCount)
        history = dailyHistoryStore.history()
    }
}
