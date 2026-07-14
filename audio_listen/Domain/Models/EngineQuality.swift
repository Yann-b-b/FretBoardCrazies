enum ChordFunction: Hashable {
    case tonic
    case subdominant
    case dominant
}

struct EngineQuality: Hashable {
    let id: String
    let formula: [Int]
    let isDominant: Bool
    let isMinorSeventh: Bool
    let function: ChordFunction
}

enum EngineQualities {
    static let maj7 = EngineQuality(id: "maj7", formula: [0, 4, 7, 11], isDominant: false, isMinorSeventh: false, function: .tonic)
    static let m7 = EngineQuality(id: "m7", formula: [0, 3, 7, 10], isDominant: false, isMinorSeventh: true, function: .subdominant)
    static let dom7 = EngineQuality(id: "7", formula: [0, 4, 7, 10], isDominant: true, isMinorSeventh: false, function: .dominant)
    static let m7b5 = EngineQuality(id: "m7b5", formula: [0, 3, 6, 10], isDominant: false, isMinorSeventh: true, function: .subdominant)
    static let six = EngineQuality(id: "6", formula: [0, 4, 7, 9], isDominant: false, isMinorSeventh: false, function: .tonic)
    static let m6 = EngineQuality(id: "m6", formula: [0, 3, 7, 9], isDominant: false, isMinorSeventh: false, function: .tonic)
    static let sixNine = EngineQuality(id: "6/9", formula: [0, 4, 7, 9, 14], isDominant: false, isMinorSeventh: false, function: .tonic)
    static let maj9 = EngineQuality(id: "maj9", formula: [0, 4, 7, 11, 14], isDominant: false, isMinorSeventh: false, function: .tonic)
    static let maj7sharp11 = EngineQuality(id: "maj7#11", formula: [0, 4, 7, 11, 18], isDominant: false, isMinorSeventh: false, function: .tonic)
    static let dom9 = EngineQuality(id: "9", formula: [0, 4, 7, 10, 14], isDominant: true, isMinorSeventh: false, function: .dominant)
    static let dom13 = EngineQuality(id: "13", formula: [0, 4, 7, 10, 14, 21], isDominant: true, isMinorSeventh: false, function: .dominant)
    static let dom7flat9 = EngineQuality(id: "7b9", formula: [0, 4, 7, 10, 13], isDominant: true, isMinorSeventh: false, function: .dominant)
    static let dom7sharp9 = EngineQuality(id: "7#9", formula: [0, 4, 7, 10, 15], isDominant: true, isMinorSeventh: false, function: .dominant)
    static let dom7sharp5 = EngineQuality(id: "7#5", formula: [0, 4, 8, 10], isDominant: true, isMinorSeventh: false, function: .dominant)
    static let dom7alt = EngineQuality(id: "7alt", formula: [0, 4, 10, 13, 15, 18, 20], isDominant: true, isMinorSeventh: false, function: .dominant)
    static let dom7sus4 = EngineQuality(id: "7sus4", formula: [0, 5, 7, 10], isDominant: true, isMinorSeventh: false, function: .dominant)
    static let dom9sus4 = EngineQuality(id: "9sus4", formula: [0, 5, 7, 10, 14], isDominant: true, isMinorSeventh: false, function: .dominant)
    static let dim7 = EngineQuality(id: "dim7", formula: [0, 3, 6, 9], isDominant: false, isMinorSeventh: false, function: .dominant)
    static let m9 = EngineQuality(id: "m9", formula: [0, 3, 7, 10, 14], isDominant: false, isMinorSeventh: true, function: .subdominant)
    static let m11 = EngineQuality(id: "m11", formula: [0, 3, 7, 10, 14, 17], isDominant: false, isMinorSeventh: true, function: .subdominant)
    static let m13 = EngineQuality(id: "m13", formula: [0, 3, 7, 10, 14, 17, 21], isDominant: false, isMinorSeventh: true, function: .subdominant)
    static let mMaj7 = EngineQuality(id: "m(maj7)", formula: [0, 3, 7, 11], isDominant: false, isMinorSeventh: false, function: .tonic)
    static let m6Nine = EngineQuality(id: "m6/9", formula: [0, 3, 7, 9, 14], isDominant: false, isMinorSeventh: false, function: .tonic)

    static let all: [EngineQuality] = [
        maj7, m7, dom7, m7b5, six, m6, sixNine, maj9, maj7sharp11,
        dom9, dom13, dom7flat9, dom7sharp9, dom7sharp5, dom7alt, dom7sus4, dom9sus4,
        dim7, m9, m11, m13, mMaj7, m6Nine,
    ]

    static func byId(_ id: String) -> EngineQuality? {
        all.first { $0.id == id }
    }

    static func isDominant(_ id: String) -> Bool {
        byId(id)?.isDominant ?? false
    }

    static func isMinorSeventh(_ id: String) -> Bool {
        byId(id)?.isMinorSeventh ?? false
    }
}
