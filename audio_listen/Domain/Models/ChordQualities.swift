enum ChordQualities {
    static let maj7 = ChordQuality(id: "maj7", name: "Major 7", symbol: "maj7", formula: [0, 4, 7, 11])
    static let m7 = ChordQuality(id: "m7", name: "Minor 7", symbol: "m7", formula: [0, 3, 7, 10])
    static let dom7 = ChordQuality(id: "7", name: "Dominant 7", symbol: "7", formula: [0, 4, 7, 10])
    static let m7b5 = ChordQuality(id: "m7b5", name: "Minor 7♭5", symbol: "m7♭5", formula: [0, 3, 6, 10])
    static let six = ChordQuality(id: "6", name: "Major 6", symbol: "6", formula: [0, 4, 7, 9])
    static let m6 = ChordQuality(id: "m6", name: "Minor 6", symbol: "m6", formula: [0, 3, 7, 9])
    static let sixNine = ChordQuality(id: "6/9", name: "Six-Nine", symbol: "6/9", formula: [0, 4, 7, 9, 14])
    static let maj9 = ChordQuality(id: "maj9", name: "Major 9", symbol: "maj9", formula: [0, 4, 7, 11, 14])
    static let maj7sharp11 = ChordQuality(id: "maj7#11", name: "Major 7♯11", symbol: "maj7♯11", formula: [0, 4, 7, 11, 18])
    static let dom9 = ChordQuality(id: "9", name: "Dominant 9", symbol: "9", formula: [0, 4, 7, 10, 14])
    static let dom13 = ChordQuality(id: "13", name: "Dominant 13", symbol: "13", formula: [0, 4, 7, 10, 14, 21])
    static let dom7flat9 = ChordQuality(id: "7b9", name: "Dominant 7♭9", symbol: "7♭9", formula: [0, 4, 7, 10, 13])
    static let dom7sharp9 = ChordQuality(id: "7#9", name: "Dominant 7♯9", symbol: "7♯9", formula: [0, 4, 7, 10, 15])
    static let dom7sharp5 = ChordQuality(id: "7#5", name: "Dominant 7♯5", symbol: "7♯5", formula: [0, 4, 8, 10])
    static let dom7alt = ChordQuality(id: "7alt", name: "Altered Dominant", symbol: "7alt", formula: [0, 4, 10, 13, 15, 18, 20])
    static let dom7sus4 = ChordQuality(id: "7sus4", name: "Dominant 7 Sus4", symbol: "7sus4", formula: [0, 5, 7, 10])
    static let dom9sus4 = ChordQuality(id: "9sus4", name: "Dominant 9 Sus4", symbol: "9sus4", formula: [0, 5, 7, 10, 14])
    static let dim7 = ChordQuality(id: "dim7", name: "Diminished 7", symbol: "°7", formula: [0, 3, 6, 9])
    static let m9 = ChordQuality(id: "m9", name: "Minor 9", symbol: "m9", formula: [0, 3, 7, 10, 14])
    static let m11 = ChordQuality(id: "m11", name: "Minor 11", symbol: "m11", formula: [0, 3, 7, 10, 14, 17])
    static let m13 = ChordQuality(id: "m13", name: "Minor 13", symbol: "m13", formula: [0, 3, 7, 10, 14, 17, 21])
    static let mMaj7 = ChordQuality(id: "m(maj7)", name: "Minor-Major 7", symbol: "m(maj7)", formula: [0, 3, 7, 11])
    static let m6Nine = ChordQuality(id: "m6/9", name: "Minor Six-Nine", symbol: "m6/9", formula: [0, 3, 7, 9, 14])

    static let all: [ChordQuality] = [
        maj7, m7, dom7, m7b5, six, m6, sixNine, maj9, maj7sharp11,
        dom9, dom13, dom7flat9, dom7sharp9, dom7sharp5, dom7alt, dom7sus4, dom9sus4,
        dim7, m9, m11, m13, mMaj7, m6Nine,
    ]

    static func byId(_ id: String) -> ChordQuality? {
        all.first { $0.id == id }
    }
}
