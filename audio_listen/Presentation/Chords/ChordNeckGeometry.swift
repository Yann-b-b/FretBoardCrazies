import CoreGraphics

struct ChordNeckGeometry {
    let size: CGSize
    let windowFrets: Int
    let centerFret: Double

    init(size: CGSize, windowFrets: Int, centerFret: Double) {
        self.size = size
        self.windowFrets = windowFrets
        self.centerFret = centerFret
    }

    private var cellWidth: CGFloat { size.width / CGFloat(windowFrets) }

    func x(forFret fret: Double) -> CGFloat {
        size.width / 2 + CGFloat(fret - centerFret) * cellWidth
    }

    func stringY(_ string: Int) -> CGFloat {
        let inset = size.height / CGFloat(7)
        return inset * CGFloat(string)
    }
}
