enum Mode: Hashable {
    case major
    case minor
}

struct Key: Hashable {
    let tonic: NoteName
    let mode: Mode
}

struct ChordSymbol: Hashable {
    let degree: Int
    let qualityId: String
}
