protocol DrillProgressRepositoryProtocol {
    func loadAll() -> [DrillItemKey: ItemStats]
    func save(_ stats: [DrillItemKey: ItemStats])
    func loadAll(for instrument: Instrument) -> [DrillItemKey: ItemStats]
    func save(_ stats: [DrillItemKey: ItemStats], for instrument: Instrument)
}
