import SwiftUI

struct FretboardView: View {
    var highlightedString: Int? = nil
    var highlightedPosition: FretPosition? = nil
    var revealLabel: String? = nil
    var heatmap: [DrillItemKey: MasteryLevel] = [:]

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
                if let position = highlightedPosition {
                    targetDot(geo, position: position)
                }
            }
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
}

#Preview {
    FretboardView(highlightedPosition: FretPosition(string: 5, fret: 3), revealLabel: "C")
        .padding()
}
