struct StringSetPreset: Identifiable, Equatable {
    let id: String
    let label: String
    let strings: Set<Int>
}

enum StringSetPresets {
    static let all: [StringSetPreset] = [
        StringSetPreset(id: "EA", label: "E · A", strings: [6, 5]),
        StringSetPreset(id: "EAD", label: "E · A · D", strings: [6, 5, 4]),
        StringSetPreset(id: "EADG", label: "E · A · D · G", strings: [6, 5, 4, 3]),
        StringSetPreset(id: "EADGB", label: "E · A · D · G · B", strings: [6, 5, 4, 3, 2]),
        StringSetPreset(id: "ALL", label: "All 6", strings: Set(1...Instruments.guitar.stringCount))
    ]

    static let singles: [StringSetPreset] = [
        StringSetPreset(id: "S6", label: "Low E", strings: [6]),
        StringSetPreset(id: "S5", label: "A", strings: [5]),
        StringSetPreset(id: "S4", label: "D", strings: [4]),
        StringSetPreset(id: "S3", label: "G", strings: [3]),
        StringSetPreset(id: "S2", label: "B", strings: [2]),
        StringSetPreset(id: "S1", label: "High e", strings: [1])
    ]

    static let choices: [StringSetPreset] = all + singles

    static let defaultStrings: Set<Int> = [6, 5]
    static let defaultChoice: StringSetPreset = choices.first { $0.strings == defaultStrings } ?? all[0]
}
