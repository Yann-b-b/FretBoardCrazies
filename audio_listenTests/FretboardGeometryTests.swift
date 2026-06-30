import CoreGraphics
import Testing
@testable import audio_listen

struct FretboardGeometryTests {
    let geo = FretboardGeometry(size: CGSize(width: 600, height: 250), stringCount: 6, fretCount: 12)

    @Test func string1IsAboveString6() {
        #expect(geo.stringY(1) < geo.stringY(6))
    }

    @Test func openFretIsLeftOfFret12() {
        #expect(geo.point(string: 3, fret: 0).x < geo.point(string: 3, fret: 12).x)
    }

    @Test func pointsStayWithinBounds() {
        for string in 1...6 {
            for fret in 0...12 {
                let p = geo.point(string: string, fret: fret)
                #expect(p.x >= 0 && p.x <= 600)
                #expect(p.y >= 0 && p.y <= 250)
            }
        }
    }

    @Test func hitTestRoundTripsPointForEveryPosition() {
        for string in 1...6 {
            for fret in 0...12 {
                let p = geo.point(string: string, fret: fret)
                #expect(geo.hitTest(point: p) == FretPosition(string: string, fret: fret))
            }
        }
    }

    @Test func hitTestReturnsNilOutsideTheBoard() {
        #expect(geo.hitTest(point: CGPoint(x: -10, y: 125)) == nil)
        #expect(geo.hitTest(point: CGPoint(x: 300, y: 1000)) == nil)
    }
}
