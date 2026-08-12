enum Explanations {
    static func text(for ruleId: SuggestionRuleId) -> (short: String, long: String) {
        switch ruleId {
        case .resolveDominant:
            return ("resolves home", "the 7th of V falls a half-step to the 3rd of I while a common tone holds.")
        case .iiToV:
            return ("sets up the V", "ii→V is the core jazz motion; the 7th of ii falls a half-step to the 3rd of V.")
        case .diatonicMotion:
            return ("moves within the key", "a diatonic neighbor reached by a fourth, fifth, or nearest scale step.")
        case .tonicColor:
            return ("colors the tonic", "6/9 and maj7♯11 rest without the maj7 leading-tone bite (the 11 is the avoid note).")
        case .dominantUpgrade:
            return ("richer dominant", "adds the 9th or 13th on top of the dominant 7th without altering its pull to the tonic.")
        case .secondaryDominant:
            return ("V7 of the next chord", "a dominant borrowed to tonicize the next target — e.g. A7 pulls to Dm (ii).")
        case .tritoneSub:
            return ("♭II7 — tritone sub", "D♭7 subs for G7: same 3rd & 7th, and the bass moves chromatically D♭→C.")
        case .modeMixtureIiHalfDim:
            return ("borrow the ♭6", "ii7 → iiø7 borrows ♭6 from the parallel minor; signals a minor ii–V.")
        case .modeMixtureIv:
            return ("backdoor to I", "iv m7 → ♭VII7 resolves to I from below (borrowed from parallel minor).")
        case .dominantAlter:
            return ("alter the dominant", "♭9/♯9/♯11/♭13 are tendency tones pulling into the tonic; e.g. 13♯11 = a D triad over the dominant.")
        case .minorLineCliche:
            return ("minor-line cliché", "the inner voice walks down root→7→♭7→6 over the minor tonic (My Funny Valentine).")
        case .dimPassing:
            return ("passing dim7", "this dim7 is a rootless ♭9 dominant pulling up to the next chord.")
        case .dimResolve:
            return ("dim7 resolves up", "the passing dim7 resolves up a half-step into the next diatonic chord.")
        case .susDelay:
            return ("delays the resolution", "sus4 suspends the dominant's 3rd, holding off its resolution before it lands.")
        case .extendedColor:
            return ("extended color", "adds the 9th, 11th, or 13th as a color tone consistent with the chord's function.")
        }
    }
}
