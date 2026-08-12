struct VoicingPosition: Hashable {
    let string: Int
    let fretOffset: Int
    let finger: Int
}

struct Voicing: Hashable {
    let qualityId: String
    let rootString: RootString
    let positions: [VoicingPosition]
}
