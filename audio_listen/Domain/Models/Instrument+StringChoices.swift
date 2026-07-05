import Foundation

extension Instrument {
    var singleStringChoices: [StringChoice] {
        let ordered = stringsByPitch
        return ordered.map { entry in
            StringChoice(strings: [entry.number], label: singleLabel(for: entry.note, among: ordered))
        }
    }

    var cumulativeStringChoices: [StringChoice] {
        let ordered = stringsByPitch
        guard ordered.count >= 2 else { return [] }
        return (2...ordered.count).map { count in
            let included = ordered.prefix(count)
            let numbers = Set(included.map(\.number))
            let label = included.map { $0.note.name.displayName }.joined(separator: " · ")
            return StringChoice(strings: numbers, label: label)
        }
    }

    var stringChoices: [StringChoice] {
        singleStringChoices + cumulativeStringChoices
    }

    var defaultStringChoice: StringChoice {
        singleStringChoices.first ?? StringChoice(strings: [], label: "")
    }

    private var stringsByPitch: [(number: Int, note: Note)] {
        strings.enumerated()
            .map { (number: $0.offset + 1, note: $0.element.openNote) }
            .sorted { $0.note.midiNumber < $1.note.midiNumber }
    }

    private func singleLabel(for note: Note, among ordered: [(number: Int, note: Note)]) -> String {
        let sameName = ordered.filter { $0.note.name == note.name }
        switch sameName.count {
        case 1:
            return note.name.displayName
        case 2:
            let isLowest = sameName.first?.note.midiNumber == note.midiNumber
            return (isLowest ? "Low " : "High ") + note.name.displayName
        default:
            return note.displayName
        }
    }
}
