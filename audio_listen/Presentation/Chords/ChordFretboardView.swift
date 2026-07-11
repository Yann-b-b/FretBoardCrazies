// audio_listen/Presentation/Chords/ChordFretboardView.swift
import SwiftUI

struct ChordFretboardView: View {
    let placedChord: PlacedChord
    var showFingering: Bool = true
    private let fretCount = 15
    private let stringCount = 6

    var body: some View {
        GeometryReader { proxy in
            let geo = FretboardGeometry(size: proxy.size, stringCount: stringCount, fretCount: fretCount)
            ZStack {
                fretLines(geo)
                strings(geo)
                inlays(geo)
                if showFingering {
                    mutedMarkers(geo)
                    dots(geo)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: placedChord)
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

    private func strings(_ geo: FretboardGeometry) -> some View {
        ForEach(1...stringCount, id: \.self) { string in
            Path { p in
                p.move(to: CGPoint(x: 0, y: geo.stringY(string)))
                p.addLine(to: CGPoint(x: geo.size.width, y: geo.stringY(string)))
            }
            .stroke(Color.gray.opacity(0.6), lineWidth: 1 + CGFloat(string - 1) * 0.15)
        }
    }

    private func inlays(_ geo: FretboardGeometry) -> some View {
        let inlayFrets = [3, 5, 7, 9, 12, 15]
        let centerY = geo.size.height / 2
        return ForEach(inlayFrets, id: \.self) { fret in
            Circle().fill(Color(white: 0.3)).frame(width: 8, height: 8)
                .position(x: geo.point(string: 1, fret: fret).x, y: centerY)
        }
    }

    private func dots(_ geo: FretboardGeometry) -> some View {
        ForEach(1...stringCount, id: \.self) { string in
            if let note = placedChord.notes.first(where: { $0.string == string }) {
                let point = geo.point(string: string, fret: note.fret)
                ZStack {
                    Circle().fill(note.isRoot ? Color.orange : Color(white: 0.93))
                    Text("\(note.finger)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(note.isRoot ? Color.black : Color(white: 0.1))
                }
                .frame(width: 24, height: 24)
                .position(point)
                .transition(.opacity)
            }
        }
    }

    private func mutedMarkers(_ geo: FretboardGeometry) -> some View {
        ForEach(1...stringCount, id: \.self) { string in
            if !placedChord.notes.contains(where: { $0.string == string }) {
                Text("✕")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.gray)
                    .position(x: geo.point(string: string, fret: 0).x, y: geo.stringY(string))
                    .transition(.opacity)
            }
        }
    }
}

#Preview {
    let m7 = Voicings.voicing(qualityId: "m7", rootString: .e6)!
    let placed = ChordPlacement.place(voicing: m7, rootPitchClass: 7, instrument: Instruments.guitar)
    ChordFretboardView(placedChord: placed).padding()
}
