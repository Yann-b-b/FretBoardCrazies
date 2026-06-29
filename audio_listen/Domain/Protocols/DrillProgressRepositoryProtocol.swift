protocol DrillProgressRepositoryProtocol {
    func loadAll() -> [DrillItemKey: ItemStats]
    func save(_ stats: [DrillItemKey: ItemStats])
}
