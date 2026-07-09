enum ChordNaming {
    static func rootName(tonic: NoteName, degree: Int) -> NoteName {
        NoteName(rawValue: (((tonic.semitonesFromC + degree) % 12) + 12) % 12)!
    }

    static func displayName(step: ProgressionStep, tonic: NoteName) -> String {
        let root = rootName(tonic: tonic, degree: step.degree)
        let quality = ChordQualities.byId(step.qualityId)!
        return root.displayName + quality.symbol
    }
}
