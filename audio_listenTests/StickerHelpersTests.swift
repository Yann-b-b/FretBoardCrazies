import XCTest
@testable import audio_listen

final class StickerHelpersTests: XCTestCase {
    func testSmallFlameForLowCombos() {
        XCTAssertEqual(flameAsset(for: 2), "flame-small")
        XCTAssertEqual(flameAsset(for: 4), "flame-small")
    }

    func testLargeFlameAtFiveAndAbove() {
        XCTAssertEqual(flameAsset(for: 5), "flame-large")
        XCTAssertEqual(flameAsset(for: 12), "flame-large")
    }
}
