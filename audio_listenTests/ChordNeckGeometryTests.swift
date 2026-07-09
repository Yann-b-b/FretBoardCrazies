import CoreGraphics
import Testing
@testable import audio_listen

struct ChordNeckGeometryTests {
    private let size = CGSize(width: 300, height: 140)

    @Test func stringOneIsAboveStringSix() {
        let geo = ChordNeckGeometry(size: size, windowFrets: 6, centerFret: 5)
        #expect(geo.stringY(1) < geo.stringY(6))
    }

    @Test func centerFretSitsAtHorizontalCenter() {
        let geo = ChordNeckGeometry(size: size, windowFrets: 6, centerFret: 5)
        #expect(abs(geo.x(forFret: 5) - size.width / 2) < 0.5)
    }

    @Test func slidingTheCenterMovesFretsLeft() {
        let low = ChordNeckGeometry(size: size, windowFrets: 6, centerFret: 3)
        let high = ChordNeckGeometry(size: size, windowFrets: 6, centerFret: 8)
        // Fret 5 is right of center when centered on 3, left of center when centered on 8.
        #expect(low.x(forFret: 5) > size.width / 2)
        #expect(high.x(forFret: 5) < size.width / 2)
    }
}
