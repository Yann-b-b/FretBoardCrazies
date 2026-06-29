import Foundation

struct UserDefaultsDrillProgressRepository: DrillProgressRepositoryProtocol {
    static let userDefaultsKey = "audio_listen_drill_progress"

    private struct Entry: Codable {
        let key: DrillItemKey
        let stats: ItemStats
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadAll() -> [DrillItemKey: ItemStats] {
        guard let data = defaults.data(forKey: Self.userDefaultsKey),
              let entries = try? JSONDecoder().decode([Entry].self, from: data) else {
            return [:]
        }
        return Dictionary(entries.map { ($0.key, $0.stats) }, uniquingKeysWith: { _, last in last })
    }

    func save(_ stats: [DrillItemKey: ItemStats]) {
        let entries = stats.map { Entry(key: $0.key, stats: $0.value) }
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: Self.userDefaultsKey)
    }
}
