enum ChordQualities {
    static let maj7 = ChordQuality(id: "maj7", name: "Major 7", symbol: "maj7", formula: [0, 4, 7, 11])
    static let m7 = ChordQuality(id: "m7", name: "Minor 7", symbol: "m7", formula: [0, 3, 7, 10])
    static let dom7 = ChordQuality(id: "7", name: "Dominant 7", symbol: "7", formula: [0, 4, 7, 10])
    static let m7b5 = ChordQuality(id: "m7b5", name: "Minor 7♭5", symbol: "m7♭5", formula: [0, 3, 6, 10])
    static let six = ChordQuality(id: "6", name: "Major 6", symbol: "6", formula: [0, 4, 7, 9])
    static let m6 = ChordQuality(id: "m6", name: "Minor 6", symbol: "m6", formula: [0, 3, 7, 9])

    static let all: [ChordQuality] = [maj7, m7, dom7, m7b5, six, m6]

    static func byId(_ id: String) -> ChordQuality? {
        all.first { $0.id == id }
    }
}
