import AVFoundation

final class ComboSoundPlayer {
    private var players: [String: AVAudioPlayer] = [:]
    private var lastTier: ComboTier = .none

    private let hitFiles: [ComboTier: String] = [
        .one: "combo-hit-1",
        .two: "combo-hit-2",
        .three: "combo-hit-3",
        .four: "combo-hit-4"
    ]

    private let tierUpFiles: [ComboTier: String] = [
        .two: "combo-tierup-2",
        .three: "combo-tierup-3",
        .four: "combo-tierup-4"
    ]

    func play(combo: Int) {
        let tier = ComboTier.tier(for: combo)
        guard tier != .none else {
            lastTier = tier
            return
        }
        if tier.rawValue > lastTier.rawValue, let stinger = tierUpFiles[tier] {
            play(named: stinger)
        }
        if let hit = hitFiles[tier] {
            play(named: hit)
        }
        lastTier = tier
    }

    private func play(named name: String) {
        guard let player = player(named: name) else { return }
        player.currentTime = 0
        player.play()
    }

    private func player(named name: String) -> AVAudioPlayer? {
        if let existing = players[name] { return existing }
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.prepareToPlay()
        players[name] = player
        return player
    }
}
