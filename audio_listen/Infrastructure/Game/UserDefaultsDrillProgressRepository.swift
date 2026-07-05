import Foundation

struct UserDefaultsDrillProgressRepository: DrillProgressRepositoryProtocol {
    static let userDefaultsKey = "audio_listen_drill_progress"

    static func userDefaultsKey(for instrument: Instrument) -> String {
        "audio_listen_drill_progress.\(instrument.id)"
    }

    private struct Entry: Codable {
        let key: DrillItemKey
        let stats: ItemStats
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadAll() -> [DrillItemKey: ItemStats] {
        decode(defaults.data(forKey: Self.userDefaultsKey))
    }

    func save(_ stats: [DrillItemKey: ItemStats]) {
        encode(stats, forKey: Self.userDefaultsKey)
    }

    func loadAll(for instrument: Instrument) -> [DrillItemKey: ItemStats] {
        decode(defaults.data(forKey: Self.userDefaultsKey(for: instrument)))
    }

    func save(_ stats: [DrillItemKey: ItemStats], for instrument: Instrument) {
        encode(stats, forKey: Self.userDefaultsKey(for: instrument))
    }

    private func decode(_ data: Data?) -> [DrillItemKey: ItemStats] {
        guard let data, let entries = try? JSONDecoder().decode([Entry].self, from: data) else {
            return [:]
        }
        return Dictionary(entries.map { ($0.key, $0.stats) }, uniquingKeysWith: { _, last in last })
    }

    private func encode(_ stats: [DrillItemKey: ItemStats], forKey key: String) {
        let entries = stats.map { Entry(key: $0.key, stats: $0.value) }
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: key)
    }
}
