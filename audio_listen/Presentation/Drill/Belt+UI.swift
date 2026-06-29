import SwiftUI

extension Belt {
    var color: Color {
        switch self {
        case .white: return Color(white: 0.85)
        case .yellow: return .yellow
        case .orange: return .orange
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .brown: return .brown
        case .black: return .black
        }
    }

    var symbolName: String { "medal.fill" }
}
