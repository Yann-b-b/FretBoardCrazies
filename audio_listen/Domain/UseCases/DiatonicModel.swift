enum DiatonicModel {
    private static let majorTable: [ChordSymbol] = [
        ChordSymbol(degree: 0, qualityId: "maj7"),
        ChordSymbol(degree: 2, qualityId: "m7"),
        ChordSymbol(degree: 4, qualityId: "m7"),
        ChordSymbol(degree: 5, qualityId: "maj7"),
        ChordSymbol(degree: 7, qualityId: "7"),
        ChordSymbol(degree: 9, qualityId: "m7"),
        ChordSymbol(degree: 11, qualityId: "m7b5"),
    ]

    private static let minorTable: [ChordSymbol] = [
        ChordSymbol(degree: 0, qualityId: "m7"),
        ChordSymbol(degree: 2, qualityId: "m7b5"),
        ChordSymbol(degree: 3, qualityId: "maj7"),
        ChordSymbol(degree: 5, qualityId: "m7"),
        ChordSymbol(degree: 7, qualityId: "7"),
        ChordSymbol(degree: 8, qualityId: "maj7"),
        ChordSymbol(degree: 10, qualityId: "7"),
        ChordSymbol(degree: 11, qualityId: "dim7"),
    ]

    private static let majorTargets = [2, 4, 5, 7, 9]
    private static let minorTargets = [3, 5, 7, 8, 10]

    static func diatonic(_ key: Key) -> [ChordSymbol] {
        key.mode == .major ? majorTable : minorTable
    }

    static func diaQual(_ degree: Int, _ key: Key) -> String? {
        diatonic(key).first { $0.degree == degree }?.qualityId
    }

    static func isDiatonic(_ c: ChordSymbol, _ key: Key) -> Bool {
        diaQual(c.degree, key) == c.qualityId
    }

    static func isTonicHere(_ c: ChordSymbol) -> Bool {
        c.degree == 0
    }

    static func targets(_ key: Key) -> [Int] {
        key.mode == .major ? majorTargets : minorTargets
    }

    static func resolutionQualityAt(_ degree: Int, _ key: Key) -> String {
        guard degree != 0 else {
            return key.mode == .major ? "maj7" : "m6"
        }
        return diaQual(degree, key) ?? "maj7"
    }
}
