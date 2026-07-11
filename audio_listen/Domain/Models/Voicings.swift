// E6-rooted movable forms. Each string's interval from the root
// (verified against its quality's formula in ChordFormulaConformanceTests):
//   s6:o  s5:(5+o)  s4:(10+o)  s3:(3+o)  s2:(7+o)   (mod 12, o = fretOffset)
enum Voicings {
    static let all: [Voicing] = [
        Voicing(qualityId: "maj7", rootString: .e6, positions: [
            VoicingPosition(string: 6, fretOffset: 0, finger: 1),
            VoicingPosition(string: 4, fretOffset: 1, finger: 3),
            VoicingPosition(string: 3, fretOffset: 1, finger: 2),
            VoicingPosition(string: 2, fretOffset: 0, finger: 1),
        ]),
        Voicing(qualityId: "7", rootString: .e6, positions: [
            VoicingPosition(string: 6, fretOffset: 0, finger: 1),
            VoicingPosition(string: 4, fretOffset: 0, finger: 1),
            VoicingPosition(string: 3, fretOffset: 1, finger: 2),
            VoicingPosition(string: 2, fretOffset: 0, finger: 1),
        ]),
        Voicing(qualityId: "m7", rootString: .e6, positions: [
            VoicingPosition(string: 6, fretOffset: 0, finger: 1),
            VoicingPosition(string: 4, fretOffset: 0, finger: 1),
            VoicingPosition(string: 3, fretOffset: 0, finger: 1),
            VoicingPosition(string: 2, fretOffset: 0, finger: 1),
        ]),
        Voicing(qualityId: "m7b5", rootString: .e6, positions: [
            VoicingPosition(string: 6, fretOffset: 0, finger: 1),
            VoicingPosition(string: 5, fretOffset: 1, finger: 2),
            VoicingPosition(string: 4, fretOffset: 0, finger: 1),
            VoicingPosition(string: 3, fretOffset: 0, finger: 1),
        ]),
        Voicing(qualityId: "6", rootString: .e6, positions: [
            VoicingPosition(string: 6, fretOffset: 0, finger: 1),
            VoicingPosition(string: 4, fretOffset: 2, finger: 3),
            VoicingPosition(string: 3, fretOffset: 1, finger: 2),
            VoicingPosition(string: 2, fretOffset: 2, finger: 4),
        ]),
        Voicing(qualityId: "m6", rootString: .e6, positions: [
            VoicingPosition(string: 6, fretOffset: 0, finger: 1),
            VoicingPosition(string: 4, fretOffset: 2, finger: 3),
            VoicingPosition(string: 3, fretOffset: 0, finger: 1),
            VoicingPosition(string: 2, fretOffset: 2, finger: 4),
        ]),
    ]

    static func voicing(qualityId: String, rootString: RootString) -> Voicing? {
        all.first { $0.qualityId == qualityId && $0.rootString == rootString }
    }
}
