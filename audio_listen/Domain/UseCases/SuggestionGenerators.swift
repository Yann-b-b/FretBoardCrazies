enum SuggestionGenerators {
    static func all(current: ChordSymbol, key: Key) -> [ChordSuggestion] {
        var result: [ChordSuggestion] = []
        result += resolveDominant(current: current, key: key)
        result += iiToV(current: current, key: key)
        result += diatonicMotion(current: current, key: key)
        result += tonicColor(current: current, key: key)
        result += dominantUpgrade(current: current, key: key)
        result += secondaryDominant(current: current, key: key)
        result += tritoneSub(current: current, key: key)
        result += modeMixtureIiHalfDim(current: current, key: key)
        result += modeMixtureIv(current: current, key: key)
        result += dominantAlter(current: current, key: key)
        result += minorLineCliche(current: current, key: key)
        result += dimPassing(current: current, key: key)
        result += dimResolve(current: current, key: key)
        result += susDelay(current: current, key: key)
        result += extendedColor(current: current, key: key)
        return result
    }

    private static func mod12(_ x: Int) -> Int {
        ((x % 12) + 12) % 12
    }

    private static func nearestDiatonicDegree(from degree: Int, direction: Int, key: Key) -> Int {
        var candidate = mod12(degree + direction)
        while DiatonicModel.diaQual(candidate, key) == nil {
            candidate = mod12(candidate + direction)
        }
        return candidate
    }

    private static func resolveDominant(current: ChordSymbol, key: Key) -> [ChordSuggestion] {
        guard EngineQualities.isDominant(current.qualityId) else { return [] }
        let d = current.degree
        var results: [ChordSuggestion] = []

        let downFifth = mod12(d + 5)
        results.append(ChordSuggestion(
            chord: ChordSymbol(degree: downFifth, qualityId: DiatonicModel.resolutionQualityAt(downFifth, key)),
            ruleId: .resolveDominant,
            keyShiftTonicize: nil
        ))

        let downHalf = mod12(d + 11)
        if downHalf == 0 || DiatonicModel.diaQual(downHalf, key) != nil {
            results.append(ChordSuggestion(
                chord: ChordSymbol(degree: downHalf, qualityId: DiatonicModel.resolutionQualityAt(downHalf, key)),
                ruleId: .resolveDominant,
                keyShiftTonicize: nil
            ))
        }

        if d == 10 {
            results.append(ChordSuggestion(
                chord: ChordSymbol(degree: 0, qualityId: DiatonicModel.resolutionQualityAt(0, key)),
                ruleId: .resolveDominant,
                keyShiftTonicize: nil
            ))
        }

        return results
    }

    private static func iiToV(current: ChordSymbol, key: Key) -> [ChordSuggestion] {
        guard EngineQualities.isMinorSeventh(current.qualityId), !DiatonicModel.isTonicHere(current) else { return [] }
        let vDegree = mod12(current.degree + 5)
        let vQuality = current.qualityId == "m7b5" ? "7b9" : "7"
        return [ChordSuggestion(chord: ChordSymbol(degree: vDegree, qualityId: vQuality), ruleId: .iiToV, keyShiftTonicize: nil)]
    }

    private static func diatonicMotion(current: ChordSymbol, key: Key) -> [ChordSuggestion] {
        guard DiatonicModel.isDiatonic(current, key) || DiatonicModel.isTonicHere(current) else { return [] }
        let d = current.degree
        var results: [ChordSuggestion] = []

        func emit(_ degree: Int) {
            guard let quality = DiatonicModel.diaQual(degree, key) else { return }
            results.append(ChordSuggestion(chord: ChordSymbol(degree: degree, qualityId: quality), ruleId: .diatonicMotion, keyShiftTonicize: nil))
        }

        emit(mod12(d + 5))
        emit(mod12(d + 7))

        let stepUp = nearestDiatonicDegree(from: d, direction: 1, key: key)
        let stepDown = nearestDiatonicDegree(from: d, direction: -1, key: key)
        emit(stepUp)
        emit(stepDown)
        if key.mode == .minor, stepDown == 11 {
            emit(10)
        }

        return results
    }

    private static func tonicColor(current: ChordSymbol, key: Key) -> [ChordSuggestion] {
        guard DiatonicModel.isTonicHere(current) else { return [] }
        let qualities = key.mode == .major ? ["6/9", "maj9", "maj7#11"] : ["m6", "m(maj7)", "m6/9"]
        return qualities.map { ChordSuggestion(chord: ChordSymbol(degree: 0, qualityId: $0), ruleId: .tonicColor, keyShiftTonicize: nil) }
    }

    private static func dominantUpgrade(current: ChordSymbol, key: Key) -> [ChordSuggestion] {
        guard current.qualityId == "7" else { return [] }
        return ["9", "13"].map { ChordSuggestion(chord: ChordSymbol(degree: current.degree, qualityId: $0), ruleId: .dominantUpgrade, keyShiftTonicize: nil) }
    }

    private static func secondaryDominant(current: ChordSymbol, key: Key) -> [ChordSuggestion] {
        guard DiatonicModel.isDiatonic(current, key) || DiatonicModel.isTonicHere(current) else { return [] }
        return DiatonicModel.targets(key).map { target in
            ChordSuggestion(chord: ChordSymbol(degree: mod12(target + 7), qualityId: "7"), ruleId: .secondaryDominant, keyShiftTonicize: target)
        }
    }

    private static func tritoneSub(current: ChordSymbol, key: Key) -> [ChordSuggestion] {
        guard EngineQualities.isDominant(current.qualityId) else { return [] }
        return [ChordSuggestion(chord: ChordSymbol(degree: mod12(current.degree + 6), qualityId: "7"), ruleId: .tritoneSub, keyShiftTonicize: nil)]
    }

    private static func modeMixtureIiHalfDim(current: ChordSymbol, key: Key) -> [ChordSuggestion] {
        guard key.mode == .major, current.degree == 2, current.qualityId == "m7" else { return [] }
        return [ChordSuggestion(chord: ChordSymbol(degree: 2, qualityId: "m7b5"), ruleId: .modeMixtureIiHalfDim, keyShiftTonicize: nil)]
    }

    private static func modeMixtureIv(current: ChordSymbol, key: Key) -> [ChordSuggestion] {
        guard key.mode == .major, DiatonicModel.isTonicHere(current) else { return [] }
        return [ChordSuggestion(chord: ChordSymbol(degree: 5, qualityId: "m7"), ruleId: .modeMixtureIv, keyShiftTonicize: nil)]
    }

    private static func dominantAlter(current: ChordSymbol, key: Key) -> [ChordSuggestion] {
        guard EngineQualities.isDominant(current.qualityId) else { return [] }
        let d = current.degree
        let secondaryDomDegrees = Set(DiatonicModel.targets(key).map { mod12($0 + 7) })
        guard d == 7 || secondaryDomDegrees.contains(d) else { return [] }
        return ["7b9", "7#9", "7#5", "7alt"].map {
            ChordSuggestion(chord: ChordSymbol(degree: d, qualityId: $0), ruleId: .dominantAlter, keyShiftTonicize: nil)
        }
    }

    private static func minorLineCliche(current: ChordSymbol, key: Key) -> [ChordSuggestion] {
        guard key.mode == .minor, DiatonicModel.isTonicHere(current) else { return [] }
        let nextQuality: String
        switch current.qualityId {
        case "m6": nextQuality = "m(maj7)"
        case "m(maj7)": nextQuality = "m7"
        case "m7": nextQuality = "m6"
        default: return []
        }
        return [ChordSuggestion(chord: ChordSymbol(degree: 0, qualityId: nextQuality), ruleId: .minorLineCliche, keyShiftTonicize: nil)]
    }

    private static func dimPassing(current: ChordSymbol, key: Key) -> [ChordSuggestion] {
        let d = current.degree
        guard DiatonicModel.diaQual(d, key) != nil, DiatonicModel.diaQual(mod12(d + 2), key) != nil else { return [] }
        return [ChordSuggestion(chord: ChordSymbol(degree: mod12(d + 1), qualityId: "dim7"), ruleId: .dimPassing, keyShiftTonicize: nil)]
    }

    private static func dimResolve(current: ChordSymbol, key: Key) -> [ChordSuggestion] {
        guard current.qualityId == "dim7" else { return [] }
        let targetDegree = mod12(current.degree + 1)
        let quality = DiatonicModel.diaQual(targetDegree, key) ?? "m7"
        return [ChordSuggestion(chord: ChordSymbol(degree: targetDegree, qualityId: quality), ruleId: .dimResolve, keyShiftTonicize: nil)]
    }

    private static func susDelay(current: ChordSymbol, key: Key) -> [ChordSuggestion] {
        guard EngineQualities.isDominant(current.qualityId), current.degree == 7 else { return [] }
        return ["7sus4", "9sus4"].map { ChordSuggestion(chord: ChordSymbol(degree: 7, qualityId: $0), ruleId: .susDelay, keyShiftTonicize: nil) }
    }

    private static func extendedColor(current: ChordSymbol, key: Key) -> [ChordSuggestion] {
        let d = current.degree
        var results: [ChordSuggestion] = []

        if EngineQualities.isMinorSeventh(current.qualityId) {
            results += ["m9", "m11", "m13"].map {
                ChordSuggestion(chord: ChordSymbol(degree: d, qualityId: $0), ruleId: .extendedColor, keyShiftTonicize: nil)
            }
        }

        if key.mode == .major, DiatonicModel.isTonicHere(current) || d == 5 {
            results += ["maj9", "maj7#11"].map {
                ChordSuggestion(chord: ChordSymbol(degree: d, qualityId: $0), ruleId: .extendedColor, keyShiftTonicize: nil)
            }
        }

        return results
    }
}
