import Foundation

struct StringChoice: Identifiable, Equatable {
    let id: String
    let label: String
    let strings: Set<Int>

    init(strings: Set<Int>, label: String) {
        self.strings = strings
        self.label = label
        self.id = strings.sorted().map(String.init).joined(separator: "-")
    }
}
