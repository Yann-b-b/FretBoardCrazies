protocol DrillProgressRepositoryProtocol {
    func loadAll(for instrument: Instrument) -> [DrillItemKey: ItemStats]
    func save(_ stats: [DrillItemKey: ItemStats], for instrument: Instrument)
}
