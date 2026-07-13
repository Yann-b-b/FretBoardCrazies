enum SpellingRole: Hashable {
    case diatonic
    case secondaryDominant
    case flatSubstitution
    case ascendingPassing
}

enum ChordSpelling {
    private static let letterCycle: [Character] = ["C", "D", "E", "F", "G", "A", "B"]
    private static let majorScaleIntervals = [0, 2, 4, 5, 7, 9, 11]
    private static let minorScaleIntervals = [0, 2, 3, 5, 7, 8, 10]

    static func spell(degree: Int, key: Key, role: SpellingRole) -> String {
        let offset = ((degree % 12) + 12) % 12
        let targetPitchClass = (key.tonic.semitonesFromC + offset) % 12
        let tonic = tonicLetter(for: key)

        switch role {
        case .diatonic, .secondaryDominant:
            let scaleIntervals = key.mode == .major ? majorScaleIntervals : minorScaleIntervals
            guard let index = scaleIntervals.firstIndex(of: offset) else {
                fatalError("ChordSpelling.spell: degree \(offset) is not diatonic in \(key) for role \(role)")
            }
            return spellLetter(letterAt(tonic, offset: index), targetPitchClass: targetPitchClass)
        case .flatSubstitution:
            let neighbor = (offset + 1) % 12
            guard let index = majorScaleIntervals.firstIndex(of: neighbor) else {
                fatalError("ChordSpelling.spell: degree \(offset) has no flatSubstitution neighbor")
            }
            return spellLetter(letterAt(tonic, offset: index), targetPitchClass: targetPitchClass)
        case .ascendingPassing:
            let neighbor = ((offset - 1) % 12 + 12) % 12
            guard let index = majorScaleIntervals.firstIndex(of: neighbor) else {
                fatalError("ChordSpelling.spell: degree \(offset) has no ascendingPassing neighbor")
            }
            return spellLetter(letterAt(tonic, offset: index), targetPitchClass: targetPitchClass)
        }
    }

    private static func tonicLetter(for key: Key) -> Character {
        switch key.tonic.semitonesFromC {
        case 0: return "C"
        case 2: return "D"
        case 4: return "E"
        case 5: return "F"
        case 7: return "G"
        case 9: return "A"
        case 11: return "B"
        case 1: return key.mode == .major ? "D" : "C"
        case 3: return key.mode == .major ? "E" : "D"
        case 6: return "F"
        case 8: return key.mode == .major ? "A" : "G"
        case 10: return "B"
        default: fatalError("ChordSpelling.tonicLetter: invalid pitch class \(key.tonic.semitonesFromC)")
        }
    }

    private static func letterAt(_ tonicLetter: Character, offset: Int) -> Character {
        guard let base = letterCycle.firstIndex(of: tonicLetter) else {
            fatalError("ChordSpelling.letterAt: \(tonicLetter) is not a natural letter")
        }
        return letterCycle[(base + offset) % 7]
    }

    private static func naturalPitchClass(of letter: Character) -> Int {
        switch letter {
        case "C": return 0
        case "D": return 2
        case "E": return 4
        case "F": return 5
        case "G": return 7
        case "A": return 9
        case "B": return 11
        default: fatalError("ChordSpelling.naturalPitchClass: \(letter) is not a natural letter")
        }
    }

    private static func spellLetter(_ letter: Character, targetPitchClass: Int) -> String {
        var diff = (targetPitchClass - naturalPitchClass(of: letter)) % 12
        diff = (diff + 12) % 12
        if diff > 6 { diff -= 12 }

        switch diff {
        case 0: return "\(letter)"
        case 1: return "\(letter)♯"
        case -1: return "\(letter)♭"
        case 2: return "\(letter)♯♯"
        case -2: return "\(letter)♭♭"
        default: fatalError("ChordSpelling.spellLetter: unsupported accidental distance \(diff) for \(letter)")
        }
    }
}
