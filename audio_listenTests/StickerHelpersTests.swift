import XCTest
@testable import audio_listen

final class StickerHelpersTests: XCTestCase {
    func testSmallFlameForLowCombos() {
        XCTAssertEqual(flameAsset(for: 2), "flame-small")
        XCTAssertEqual(flameAsset(for: 9), "flame-small")
    }

    func testLargeFlameAtTenAndAbove() {
        XCTAssertEqual(flameAsset(for: 10), "flame-large")
        XCTAssertEqual(flameAsset(for: 25), "flame-large")
    }
}
