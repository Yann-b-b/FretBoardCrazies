import XCTest
@testable import audio_listen

final class BeltStickerTests: XCTestCase {
    func testAssetNameMatchesCatalog() {
        XCTAssertEqual(Belt.white.assetName, "belt-white")
        XCTAssertEqual(Belt.yellow.assetName, "belt-yellow")
        XCTAssertEqual(Belt.purple.assetName, "belt-purple")
        XCTAssertEqual(Belt.black.assetName, "belt-black")
    }

    func testEveryBeltHasAssetName() {
        for belt in Belt.allCases {
            XCTAssertEqual(belt.assetName, "belt-\(belt.displayName.lowercased())")
        }
    }

    func testOutranksUsesRankOrder() {
        XCTAssertTrue(Belt.black.outranks(.white))
        XCTAssertTrue(Belt.yellow.outranks(.white))
        XCTAssertFalse(Belt.white.outranks(.white))
        XCTAssertFalse(Belt.white.outranks(.black))
    }
}
