enum RootString: String, CaseIterable {
    case e6
    case a5
    case d4

    var stringNumber: Int {
        switch self {
        case .e6: return 6
        case .a5: return 5
        case .d4: return 4
        }
    }

    var label: String {
        switch self {
        case .e6: return "Low E"
        case .a5: return "A"
        case .d4: return "D"
        }
    }
}
