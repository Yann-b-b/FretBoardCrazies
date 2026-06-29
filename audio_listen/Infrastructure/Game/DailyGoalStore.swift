import Foundation

struct DailyGoalStore {
    static let userDefaultsKey = "audio_listen_daily_goal"

    private struct Record: Codable {
        var dayStart: Date
        var count: Int
    }

    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    func todayCount(now: Date) -> Int {
        guard let record = loadRecord(), calendar.isDate(record.dayStart, inSameDayAs: now) else {
            return 0
        }
        return record.count
    }

    @discardableResult
    func recordCorrect(now: Date) -> Int {
        let start = calendar.startOfDay(for: now)
        var record = loadRecord() ?? Record(dayStart: start, count: 0)
        if !calendar.isDate(record.dayStart, inSameDayAs: now) {
            record = Record(dayStart: start, count: 0)
        }
        record.count += 1
        saveRecord(record)
        return record.count
    }

    private func loadRecord() -> Record? {
        guard let data = defaults.data(forKey: Self.userDefaultsKey) else { return nil }
        return try? JSONDecoder().decode(Record.self, from: data)
    }

    private func saveRecord(_ record: Record) {
        guard let data = try? JSONEncoder().encode(record) else { return }
        defaults.set(data, forKey: Self.userDefaultsKey)
    }
}
