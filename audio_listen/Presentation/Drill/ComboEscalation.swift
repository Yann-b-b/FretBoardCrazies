import CoreGraphics

enum ComboTier: Int {
    case none, one, two, three, four

    static let tier2Threshold = 15
    static let tier3Threshold = 25
    static let tier4Threshold = 50

    static func tier(for combo: Int) -> ComboTier {
        if combo >= tier4Threshold { return .four }
        if combo >= tier3Threshold { return .three }
        if combo >= tier2Threshold { return .two }
        if combo >= 2 { return .one }
        return .none
    }
}

struct ComboVisual {
    let flameAsset: String
    let wiggleAmplitude: CGFloat
    let rainbow: Bool
}

enum ComboEscalation {
    static let maxWiggle: CGFloat = 10

    static func visual(for combo: Int) -> ComboVisual {
        let tier = ComboTier.tier(for: combo)
        let flame = (tier == .none || tier == .one) ? "flame-small" : "flame-large"
        return ComboVisual(
            flameAsset: flame,
            wiggleAmplitude: wiggle(for: combo, tier: tier),
            rainbow: tier == .four
        )
    }

    private static func wiggle(for combo: Int, tier: ComboTier) -> CGFloat {
        switch tier {
        case .none, .two:
            return 0
        case .one:
            return ramp(combo, start: 2, end: ComboTier.tier2Threshold - 1)
        case .three:
            return ramp(combo, start: ComboTier.tier3Threshold, end: ComboTier.tier4Threshold - 1)
        case .four:
            return maxWiggle
        }
    }

    private static func ramp(_ combo: Int, start: Int, end: Int) -> CGFloat {
        let fraction = CGFloat(combo - start) / CGFloat(end - start)
        return maxWiggle * min(max(fraction, 0), 1)
    }
}
