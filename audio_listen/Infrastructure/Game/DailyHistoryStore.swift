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
    static let userDefaultsKey = "audio_listen_daily_history"

    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    func history() -> [DailyRecord] {
        load().sorted { $0.dayStart < $1.dayStart }
    }

    func todayReps(now: Date) -> Int {
        load().first { calendar.isDate($0.dayStart, inSameDayAs: now) }?.reps ?? 0
    }

    @discardableResult
    func recordCorrect(now: Date, reactionTime: TimeInterval, masteredCount: Int) -> Int {
        var records = load()
        if let index = records.firstIndex(where: { calendar.isDate($0.dayStart, inSameDayAs: now) }) {
            records[index].reps += 1
            records[index].reactionSum += reactionTime
            records[index].reactionCount += 1
            records[index].masteredSnapshot = masteredCount
            save(records)
            return records[index].reps
        }
        let record = DailyRecord(
            dayStart: calendar.startOfDay(for: now),
            reps: 1,
            reactionSum: reactionTime,
            reactionCount: 1,
            masteredSnapshot: masteredCount
        )
        records.append(record)
        save(records)
        return 1
    }

    private func load() -> [DailyRecord] {
        guard let data = defaults.data(forKey: Self.userDefaultsKey),
              let records = try? JSONDecoder().decode([DailyRecord].self, from: data) else {
            return []
        }
        return records
    }

    private func save(_ records: [DailyRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: Self.userDefaultsKey)
    }
}
