import Foundation

enum DrillTuning {
    static let maxBox = 4
    static let fastReactionSeconds: TimeInterval = 3.0
    static let totalItemCount = 6 * 12

    static func universeSize(for instrument: Instrument) -> Int {
        instrument.stringCount * 12
    }
}
