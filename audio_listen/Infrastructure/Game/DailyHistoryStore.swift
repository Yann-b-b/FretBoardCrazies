import Foundation

struct DailyRecord: Codable, Equatable {
    var dayStart: Date
    var reps: Int
    var reactionSum: TimeInterval
    var reactionCount: Int
    var masteredSnapshot: Int

    var averageReaction: Double {
        reactionCount == 0 ? 0 : reactionSum / Double(reactionCount)
    }
}

struct DailyHistoryStore {
    static func userDefaultsKey(for instrument: Instrument) -> String {
        "audio_listen_daily_history.\(instrument.id)"
    }

    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    func history(for instrument: Instrument) -> [DailyRecord] {
        load(Self.userDefaultsKey(for: instrument)).sorted { $0.dayStart < $1.dayStart }
    }

    func todayReps(for instrument: Instrument, now: Date) -> Int {
        load(Self.userDefaultsKey(for: instrument)).first { calendar.isDate($0.dayStart, inSameDayAs: now) }?.reps ?? 0
    }

    func recordCorrect(for instrument: Instrument, now: Date, reactionTime: TimeInterval, masteredCount: Int) {
        record(forKey: Self.userDefaultsKey(for: instrument), now: now, reactionTime: reactionTime, masteredCount: masteredCount)
    }

    private func record(forKey key: String, now: Date, reactionTime: TimeInterval, masteredCount: Int) {
        var records = load(key)
        if let index = records.firstIndex(where: { calendar.isDate($0.dayStart, inSameDayAs: now) }) {
            records[index].reps += 1
            records[index].reactionSum += reactionTime
            records[index].reactionCount += 1
            records[index].masteredSnapshot = masteredCount
            save(records, forKey: key)
            return
        }
        let record = DailyRecord(
            dayStart: calendar.startOfDay(for: now),
            reps: 1,
            reactionSum: reactionTime,
            reactionCount: 1,
            masteredSnapshot: masteredCount
        )
        records.append(record)
        save(records, forKey: key)
    }

    private func load(_ key: String) -> [DailyRecord] {
        guard let data = defaults.data(forKey: key),
              let records = try? JSONDecoder().decode([DailyRecord].self, from: data) else {
            return []
        }
        return records
    }

    private func save(_ records: [DailyRecord], forKey key: String) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: key)
    }
}
