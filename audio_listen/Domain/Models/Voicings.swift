// E6-rooted movable forms. Each string's interval from the root
// (verified against its quality's formula in ChordFormulaConformanceTests):
//   s6:o  s5:(5+o)  s4:(10+o)  s3:(3+o)  s2:(7+o)   (mod 12, o = fretOffset)
// Built in family-grouped chunks so the Swift type-checker never has to
// infer element types across one large array literal.
enum Voicings {
    private static let majorType: [Voicing] = [
        Voicing(qualityId: "maj7", rootString: .e6, positions: [
            VoicingPosition(string: 6, fretOffset: 0, finger: 1),
            VoicingPosition(string: 4, fretOffset: 1, finger: 2),
            VoicingPosition(string: 3, fretOffset: 1, finger: 2),
            VoicingPosition(string: 2, fretOffset: 0, finger: 1),
        ]),
        Voicing(qualityId: "6", rootString: .e6, positions: [
            VoicingPosition(string: 6, fretOffset: 0, finger: 1),
            VoicingPosition(string: 4, fretOffset: -1, finger: 2),
            VoicingPosition(string: 3, fretOffset: 1, finger: 3),
            VoicingPosition(string: 2, fretOffset: 0, finger: 1),
        ]),
        Voicing(qualityId: "6/9", rootString: .e6, positions: [
            VoicingPosition(string: 6, fretOffset: 0, finger: 1),
            VoicingPosition(string: 4, fretOffset: -1, finger: 3),
            VoicingPosition(string: 3, fretOffset: -1, finger: 3),
            VoicingPosition(string: 2, fretOffset: -3, finger: 2),
        ]),
        Voicing(qualityId: "maj9", rootString: .e6, positions: [
            VoicingPosition(string: 6, fretOffset: 0, finger: 1),
            VoicingPosition(string: 4, fretOffset: 1, finger: 2),
            VoicingPosition(string: 3, fretOffset: 1, finger: 2),
            VoicingPosition(string: 2, fretOffset: 0, finger: 1),
            VoicingPosition(string: 1, fretOffset: 2, finger: 3),
        ]),
        Voicing(qualityId: "maj7#11", rootString: .e6, positions: [
            VoicingPosition(string: 6, fretOffset: 0, finger: 1),
            VoicingPosition(string: 4, fretOffset: 1, finger: 3),
            VoicingPosition(string: 3, fretOffset: 1, finger: 3),
            VoicingPosition(string: 2, fretOffset: -1, finger: 2),
            VoicingPosition(string: 1, fretOffset: -1, finger: 2),
        ]),
    ]

    private static let minorType: [Voicing] = [
        Voicing(qualityId: "m7", rootString: .e6, positions: [
            VoicingPosition(string: 6, fretOffset: 0, finger: 1),
            VoicingPosition(string: 4, fretOffset: 0, finger: 1),
            VoicingPosition(string: 3, fretOffset: 0, finger: 1),
            VoicingPosition(string: 2, fretOffset: 0, finger: 1),
        ]),
        Voicing(qualityId: "m6", rootString: .e6, positions: [
            VoicingPosition(string: 6, fretOffset: 0, finger: 1),
            VoicingPosition(string: 4, fretOffset: -1, finger: 2),
            VoicingPosition(string: 3, fretOffset: 0, finger: 1),
            VoicingPosition(string: 2, fretOffset: 0, finger: 1),
        ]),
        Voicing(qualityId: "m6/9", rootString: .e6, positions: [
            VoicingPosition(string: 6, fretOffset: 0, finger: 1),
            VoicingPosition(string: 4, fretOffset: -1, finger: 2),
            VoicingPosition(string: 3, fretOffset: 0, finger: 1),
            VoicingPosition(string: 2, fretOffset: 0, finger: 1),
            VoicingPosition(string: 1, fretOffset: 2, finger: 3),
        ]),
        Voicing(qualityId: "m7b5", rootString: .e6, positions: [
            VoicingPosition(string: 6, fretOffset: 0, finger: 1),
            VoicingPosition(string: 4, fretOffset: 0, finger: 1),
            VoicingPosition(string: 3, fretOffset: 0, finger: 1),
            VoicingPosition(string: 2, fretOffset: -1, finger: 2),
        ]),
        Voicing(qualityId: "m(maj7)", rootString: .e6, positions: [
            VoicingPosition(string: 6, fretOffset: 0, finger: 1),
            VoicingPosition(string: 4, fretOffset: 1, finger: 2),
            VoicingPosition(string: 3, fretOffset: 0, finger: 1),
            VoicingPosition(string: 2, fretOffset: 0, finger: 1),
        ]),
        Voicing(qualityId: "m9", rootString: .e6, positions: [
            VoicingPosition(string: 6, fretOffset: 0, finger: 1),
            VoicingPosition(string: 5, fretOffset: -2, finger: 2),
            VoicingPosition(string: 4, fretOffset: 0, finger: 1),
            VoicingPosition(string: 3, fretOffset: -1, finger: 3),
        ]),
        Voicing(qualityId: "m11", rootString: .e6, positions: [
            VoicingPosition(string: 6, fretOffset: 0, finger: 1),
            VoicingPosition(string: 5, fretOffset: -2, finger: 2),
            VoicingPosition(string: 4, fretOffset: 0, finger: 1),
            VoicingPosition(string: 3, fretOffset: -1, finger: 3),
            VoicingPosition(string: 2, fretOffset: -2, finger: 2),
        ]),
        Voicing(qualityId: "m13", rootString: .e6, positions: [
            VoicingPosition(string: 6, fretOffset: 0, finger: 1),
            VoicingPosition(string: 5, fretOffset: -2, finger: 2),
            VoicingPosition(string: 4, fretOffset: 0, finger: 1),
            VoicingPosition(string: 3, fretOffset: 2, finger: 3),
            VoicingPosition(string: 2, fretOffset: 2, finger: 3),
            VoicingPosition(string: 1, fretOffset: 2, finger: 3),
        ]),
    ]

    private static let dominantType: [Voicing] = [
        Voicing(qualityId: "7", rootString: .e6, positions: [
            VoicingPosition(string: 6, fretOffset: 0, finger: 1),
            VoicingPosition(string: 4, fretOffset: 0, finger: 1),
            VoicingPosition(string: 3, fretOffset: 1, finger: 2),
            VoicingPosition(string: 2, fretOffset: 0, finger: 1),
        ]),
        Voicing(qualityId: "7#5", rootString: .e6, positions: [
            VoicingPosition(string: 6, fretOffset: 0, finger: 1),
            VoicingPosition(string: 4, fretOffset: 0, finger: 1),
            VoicingPosition(string: 3, fretOffset: 1, finger: 2),
            VoicingPosition(string: 2, fretOffset: 1, finger: 2),
        ]),
        Voicing(qualityId: "7sus4", rootString: .e6, positions: [
            VoicingPosition(string: 6, fretOffset: 0, finger: 1),
            VoicingPosition(string: 4, fretOffset: 0, finger: 1),
            VoicingPosition(string: 3, fretOffset: 2, finger: 2),
            VoicingPosition(string: 2, fretOffset: 0, finger: 1),
        ]),
        Voicing(qualityId: "9", rootString: .e6, positions: [
            VoicingPosition(string: 6, fretOffset: 0, finger: 1),
            VoicingPosition(string: 5, fretOffset: -1, finger: 2),
            VoicingPosition(string: 4, fretOffset: 0, finger: 1),
            VoicingPosition(string: 3, fretOffset: -1, finger: 2),
        ]),
        Voicing(qualityId: "7b9", rootString: .e6, positions: [
            VoicingPosition(string: 6, fretOffset: 0, finger: 1),
            VoicingPosition(string: 5, fretOffset: -1, finger: 3),
            VoicingPosition(string: 4, fretOffset: 0, finger: 1),
            VoicingPosition(string: 3, fretOffset: -2, finger: 2),
        ]),
        Voicing(qualityId: "7#9", rootString: .e6, positions: [
            VoicingPosition(string: 6, fretOffset: 0, finger: 1),
            VoicingPosition(string: 5, fretOffset: -1, finger: 2),
            VoicingPosition(string: 4, fretOffset: 0, finger: 1),
            VoicingPosition(string: 3, fretOffset: 0, finger: 1),
        ]),
        Voicing(qualityId: "9sus4", rootString: .e6, positions: [
            VoicingPosition(string: 6, fretOffset: 0, finger: 1),
            VoicingPosition(string: 4, fretOffset: 0, finger: 1),
            VoicingPosition(string: 3, fretOffset: -1, finger: 3),
            VoicingPosition(string: 2, fretOffset: -2, finger: 2),
        ]),
        Voicing(qualityId: "13", rootString: .e6, positions: [
            VoicingPosition(string: 6, fretOffset: 0, finger: 1),
            VoicingPosition(string: 4, fretOffset: 0, finger: 1),
            VoicingPosition(string: 3, fretOffset: 1, finger: 2),
            VoicingPosition(string: 2, fretOffset: 2, finger: 3),
        ]),
        Voicing(qualityId: "7alt", rootString: .e6, positions: [
            VoicingPosition(string: 6, fretOffset: 0, finger: 1),
            VoicingPosition(string: 5, fretOffset: -1, finger: 2),
            VoicingPosition(string: 4, fretOffset: 0, finger: 1),
            VoicingPosition(string: 3, fretOffset: 0, finger: 1),
            VoicingPosition(string: 2, fretOffset: 1, finger: 3),
        ]),
    ]

    private static let symmetricType: [Voicing] = [
        Voicing(qualityId: "dim7", rootString: .e6, positions: [
            VoicingPosition(string: 6, fretOffset: 0, finger: 1),
            VoicingPosition(string: 4, fretOffset: -1, finger: 2),
            VoicingPosition(string: 3, fretOffset: 0, finger: 1),
            VoicingPosition(string: 2, fretOffset: -1, finger: 2),
            VoicingPosition(string: 1, fretOffset: 0, finger: 1),
        ]),
    ]

    static let all: [Voicing] = majorType + minorType + dominantType + symmetricType

    static func voicing(qualityId: String, rootString: RootString) -> Voicing? {
        all.first { $0.qualityId == qualityId && $0.rootString == rootString }
    }
}
