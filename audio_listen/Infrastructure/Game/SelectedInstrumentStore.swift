import Foundation

struct SelectedInstrumentStore {
    static let userDefaultsKey = "audio_listen_selected_instrument"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var selectedInstrument: Instrument {
        let id = defaults.string(forKey: Self.userDefaultsKey)
        return Instruments.all.first { $0.id == id } ?? Instruments.guitar
    }

    func save(_ id: String) {
        defaults.set(id, forKey: Self.userDefaultsKey)
    }
}
