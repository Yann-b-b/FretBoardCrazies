import SwiftUI

struct FretboardView: View {
    var highlightedString: Int? = nil
    var highlightedPosition: FretPosition? = nil
    var revealLabel: String? = nil
    var heatmap: [DrillItemKey: MasteryLevel] = [:]
    var onTap: ((FretPosition) -> Void)? = nil
    var wrongPosition: FretPosition? = nil

    private let stringCount = 6
    private let fretCount = 12

    var body: some View {
        GeometryReader { proxy in
            let geo = FretboardGeometry(size: proxy.size, stringCount: stringCount, fretCount: fretCount)
            ZStack {
                fretLines(geo)
                stringLines(geo)
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
        .frame(minHeight: 220)
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
        for fret in 0...fretCount where GuitarFretboard.note(at: key.string, fret: fret)?.name == key.noteName {
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
