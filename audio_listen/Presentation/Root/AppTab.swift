enum AppTab: CaseIterable, Identifiable {
    case drill
    case chords
    case suggest
    case progress
    case tuner
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .drill: "Drill"
        case .chords: "Chords"
        case .suggest: "Suggest"
        case .progress: "Progress"
        case .tuner: "Tuner"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .drill: "guitars.fill"
        case .chords: "pianokeys"
        case .suggest: "wand.and.stars"
        case .progress: "chart.bar.fill"
        case .tuner: "tuningfork"
        case .settings: "gearshape.fill"
        }
    }
}

enum ReleaseScope {
    static let shippingTabs: [AppTab] = [.drill, .progress, .tuner, .settings]
}
