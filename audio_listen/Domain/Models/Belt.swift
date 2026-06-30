enum Belt: Int, CaseIterable {
    case white, yellow, orange, green, blue, purple, brown, black

    static let thresholds: [Double] = [0.0, 0.12, 0.25, 0.40, 0.55, 0.70, 0.85, 0.97]

    var displayName: String {
        switch self {
        case .white: return "White"
        case .yellow: return "Yellow"
        case .orange: return "Orange"
        case .green: return "Green"
        case .blue: return "Blue"
        case .purple: return "Purple"
        case .brown: return "Brown"
        case .black: return "Black"
        }
    }

    func outranks(_ other: Belt) -> Bool { rawValue > other.rawValue }
}
