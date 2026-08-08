enum InputMode: CaseIterable {
    case instrument
    case tapping

    var title: String {
        switch self {
        case .instrument: "I'm playing an instrument"
        case .tapping: "I'll tap the fretboard"
        }
    }

    var systemImage: String {
        switch self {
        case .instrument: "guitars.fill"
        case .tapping: "hand.tap.fill"
        }
    }
}
