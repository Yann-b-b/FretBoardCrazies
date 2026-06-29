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
}
