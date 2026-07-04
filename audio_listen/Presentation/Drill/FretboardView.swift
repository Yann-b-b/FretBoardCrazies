import SwiftUI

struct FretboardView: View {
    var highlightedString: Int? = nil
    var highlightedPosition: FretPosition? = nil
    var revealLabel: String? = nil
    var heatmap: [DrillItemKey: MasteryLevel] = [:]
    var onTap: ((FretPosition) -> Void)? = nil
    var wrongPosition: FretPosition? = nil
    var minHeight: CGFloat = 220
    var instrument: Instrument = Instruments.guitar

    private var stringCount: Int { instrument.stringCount }
    private let fretCount = 12

    var body: some View {
        GeometryReader { proxy in
            let geo = FretboardGeometry(size: proxy.size, stringCount: stringCount, fretCount: fretCount)
            ZStack {
                fretLines(geo)
                stringLines(geo)
                inlayDots(geo)
                if let string = highlightedString {
                    stringGlow(geo, string: string)
                }
                heatmapDots(geo)
                if let position = highlightedPosition {
                    targetDot(geo, position: position)
                }
                if let position = wrongPosition {
                    wrongDot(geo, position: position)
                }
            }
            .modifier(TapToFret(geo: geo, onTap: onTap))
        }
        .frame(minHeight: minHeight)
        .background(Color(white: 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func fretLines(_ geo: FretboardGeometry) -> some View {
        ForEach(0...fretCount, id: \.self) { fret in
            let x = geo.size.width / CGFloat(fretCount + 1) * CGFloat(fret + 1)
            Path { p in
                p.move(to: CGPoint(x: x, y: geo.stringY(1)))
                p.addLine(to: CGPoint(x: x, y: geo.stringY(stringCount)))
            }
            .stroke(Color.gray.opacity(fret == 0 ? 0.9 : 0.4), lineWidth: fret == 0 ? 3 : 1)
        }
    }

    private func stringLines(_ geo: FretboardGeometry) -> some View {
        ForEach(1...stringCount, id: \.self) { string in
            Path { p in
                p.move(to: CGPoint(x: 0, y: geo.stringY(string)))
                p.addLine(to: CGPoint(x: geo.size.width, y: geo.stringY(string)))
            }
            .stroke(Color.gray.opacity(0.6), lineWidth: 1)
        }
    }

    private func inlayDots(_ geo: FretboardGeometry) -> some View {
        let singleDotFrets = [3, 5, 7, 9]
        let octaveFret = 12
        let dotColor = Color(white: 0.45)
        let dotSize: CGFloat = 10
        let centerY = geo.size.height / 2
        let stringSpacing = geo.stringY(1)
        return ZStack {
            ForEach(singleDotFrets, id: \.self) { fret in
                Circle()
                    .fill(dotColor)
                    .frame(width: dotSize, height: dotSize)
                    .position(x: geo.point(string: 1, fret: fret).x, y: centerY)
            }
            ForEach([centerY - stringSpacing, centerY + stringSpacing], id: \.self) { y in
                Circle()
                    .fill(dotColor)
                    .frame(width: dotSize, height: dotSize)
                    .position(x: geo.point(string: 1, fret: octaveFret).x, y: y)
            }
        }
    }

    private func stringGlow(_ geo: FretboardGeometry, string: Int) -> some View {
        Path { p in
            p.move(to: CGPoint(x: 0, y: geo.stringY(string)))
            p.addLine(to: CGPoint(x: geo.size.width, y: geo.stringY(string)))
        }
        .stroke(Color.yellow, lineWidth: 3)
    }

    @ViewBuilder
    private func heatmapDots(_ geo: FretboardGeometry) -> some View {
        ForEach(Array(heatmap.keys), id: \.self) { key in
            if let fret = fret(for: key), let level = heatmap[key] {
                Circle()
                    .fill(color(for: level))
                    .frame(width: 14, height: 14)
                    .position(geo.point(string: key.string, fret: fret))
            }
        }
    }

    private func fret(for key: DrillItemKey) -> Int? {
        for fret in 0...fretCount where instrument.note(at: key.string, fret: fret)?.name == key.noteName {
            return fret
        }
        return nil
    }

    private func color(for level: MasteryLevel) -> Color {
        switch level {
        case .unseen: return Color.gray.opacity(0.4)
        case .learning: return .orange
        case .mastered: return .green
        }
    }

    private func targetDot(_ geo: FretboardGeometry, position: FretPosition) -> some View {
        let point = geo.point(string: position.string, fret: position.fret)
        return ZStack {
            Circle().fill(Color.orange).frame(width: 22, height: 22).position(point)
            if let label = revealLabel {
                Text(label).font(.caption).bold().foregroundStyle(.white)
                    .position(x: point.x, y: point.y - 20)
            }
        }
    }

    private func wrongDot(_ geo: FretboardGeometry, position: FretPosition) -> some View {
        Circle()
            .fill(Color(red: 1.0, green: 0.42, blue: 0.42))
            .frame(width: 22, height: 22)
            .position(geo.point(string: position.string, fret: position.fret))
    }
}

private struct TapToFret: ViewModifier {
    let geo: FretboardGeometry
    let onTap: ((FretPosition) -> Void)?

    func body(content: Content) -> some View {
        if let onTap {
            content
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0).onEnded { value in
                        if let position = geo.hitTest(point: value.location) {
                            onTap(position)
                        }
                    }
                )
        } else {
            content
        }
    }
}

#Preview {
    FretboardView(highlightedPosition: FretPosition(string: 6, fret: 1), revealLabel: "")
        .padding()
}
