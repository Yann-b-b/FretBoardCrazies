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
        StringSetPreset(id: "ALL", label: "All 6", strings: Set(1...6))
    ]
}
