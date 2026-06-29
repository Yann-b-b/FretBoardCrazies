struct BeltRank: Equatable {
    let belt: Belt
    let fraction: Double
    let fractionToNext: Double

    static func from(stats: [DrillItemKey: ItemStats], maxBox: Int, universeSize: Int) -> BeltRank {
        let maxPoints = Double(universeSize * maxBox)
        let points = stats.values.reduce(0) { $0 + min($1.box, maxBox) }
        let fraction = maxPoints == 0 ? 0 : Double(points) / maxPoints

        var current = Belt.white
        for belt in Belt.allCases where fraction >= Belt.thresholds[belt.rawValue] {
            current = belt
        }

        if current == .black {
            return BeltRank(belt: .black, fraction: fraction, fractionToNext: 1.0)
        }
        let lower = Belt.thresholds[current.rawValue]
        let upper = Belt.thresholds[current.rawValue + 1]
        let toNext = upper == lower ? 1.0 : (fraction - lower) / (upper - lower)
        return BeltRank(belt: current, fraction: fraction, fractionToNext: max(0, min(1, toNext)))
    }
}
