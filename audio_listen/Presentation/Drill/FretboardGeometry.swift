import CoreGraphics

struct FretboardGeometry {
    let size: CGSize
    let stringCount: Int
    let fretCount: Int

    init(size: CGSize, stringCount: Int = 6, fretCount: Int = 12) {
        self.size = size
        self.stringCount = stringCount
        self.fretCount = fretCount
    }

    func stringY(_ string: Int) -> CGFloat {
        let inset = size.height / CGFloat(stringCount + 1)
        return inset * CGFloat(string)
    }

    func point(string: Int, fret: Int) -> CGPoint {
        let cellWidth = size.width / CGFloat(fretCount + 1)
        let x = cellWidth * (CGFloat(fret) + 0.5)
        return CGPoint(x: x, y: stringY(string))
    }

    func hitTest(point: CGPoint) -> FretPosition? {
        let inset = size.height / CGFloat(stringCount + 1)
        let cellWidth = size.width / CGFloat(fretCount + 1)
        guard inset > 0, cellWidth > 0 else { return nil }
        let string = Int((point.y / inset).rounded())
        let fret = Int((point.x / cellWidth).rounded(.down))
        guard string >= 1, string <= stringCount, fret >= 0, fret <= fretCount else { return nil }
        return FretPosition(string: string, fret: fret)
    }
}
