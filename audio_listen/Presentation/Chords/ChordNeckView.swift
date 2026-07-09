import SwiftUI

struct ChordNeckView: View {
    let placedChord: PlacedChord
    var showFingering: Bool = true
    private let windowFrets = 6
    private let dotRadius: CGFloat = 11

    private var centerFret: Double { Double(placedChord.rootFret) + 1.0 }

    var body: some View {
        GeometryReader { proxy in
            let geo = ChordNeckGeometry(size: proxy.size, windowFrets: windowFrets, centerFret: centerFret)
            ZStack {
                fretLines(geo)
                strings(geo)
                positionLabel(geo)
                if showFingering {
                    dots(geo)
                }
            }
            .animation(.timingCurve(0.4, 0.1, 0.2, 1, duration: 0.55), value: placedChord)
        }
        .frame(height: 150)
        .background(Color(white: 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func fretLines(_ geo: ChordNeckGeometry) -> some View {
        let lo = placedChord.rootFret - windowFrets
        let hi = placedChord.rootFret + windowFrets
        return ZStack {
            ForEach(lo...hi, id: \.self) { fret in
                let x = geo.x(forFret: Double(fret))
                Path { p in
                    p.move(to: CGPoint(x: x, y: geo.stringY(1)))
                    p.addLine(to: CGPoint(x: x, y: geo.stringY(6)))
                }
                .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                if [3, 5, 7, 9, 12, 15, 17, 19, 21].contains(fret) {
                    Circle().fill(Color(white: 0.3)).frame(width: 6, height: 6)
                        .position(x: geo.x(forFret: Double(fret) - 0.5), y: geo.stringY(3) + (geo.stringY(4) - geo.stringY(3)) / 2)
                }
            }
        }
    }

    private func strings(_ geo: ChordNeckGeometry) -> some View {
        ForEach(1...6, id: \.self) { string in
            Path { p in
                p.move(to: CGPoint(x: 0, y: geo.stringY(string)))
                p.addLine(to: CGPoint(x: geo.size.width, y: geo.stringY(string)))
            }
            .stroke(Color.gray.opacity(0.6), lineWidth: 1 + CGFloat(string - 1) * 0.15)
        }
    }

    private func positionLabel(_ geo: ChordNeckGeometry) -> some View {
        Text("\(placedChord.rootFret)fr")
            .font(.caption2.monospaced())
            .foregroundStyle(Color.gray)
            .position(x: geo.x(forFret: Double(placedChord.rootFret) - 0.5), y: geo.stringY(1) - 8)
    }

    private func dots(_ geo: ChordNeckGeometry) -> some View {
        ForEach(placedChord.positions, id: \.self) { position in
            let isRoot = position == placedChord.rootPosition
            Circle()
                .fill(isRoot ? Color.orange : Color(white: 0.93))
                .frame(width: dotRadius * 2, height: dotRadius * 2)
                .position(x: geo.x(forFret: Double(position.fret) - 0.5), y: geo.stringY(position.string))
        }
    }
}

#Preview {
    let m7 = Voicings.voicing(qualityId: "m7", rootString: .e6)!
    let placed = ChordPlacement.place(voicing: m7, rootPitchClass: 7, instrument: Instruments.guitar)
    ChordNeckView(placedChord: placed).padding()
}
