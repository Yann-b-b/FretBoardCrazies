import SwiftUI

struct FloatingBeltsView: View {
    private struct Sprite: Identifiable {
        let id: Int
        let assetName: String
        let xFraction: CGFloat
        let yFraction: CGFloat
        let phase: Double
    }

    @State private var animate = false

    private let sprites = FloatingBeltsView.makeSprites()

    var body: some View {
        GeometryReader { proxy in
            ForEach(sprites) { sprite in
                Image(sprite.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .opacity(0.35)
                    .rotationEffect(.degrees(animate ? 8 : -8))
                    .offset(y: animate ? -10 : 10)
                    .position(
                        x: proxy.size.width * sprite.xFraction,
                        y: proxy.size.height * sprite.yFraction
                    )
                    .animation(
                        .easeInOut(duration: 3.0)
                            .repeatForever(autoreverses: true)
                            .delay(sprite.phase),
                        value: animate
                    )
            }
        }
        .allowsHitTesting(false)
        .onAppear { animate = true }
    }

    private static func makeSprites() -> [Sprite] {
        Belt.allCases.enumerated().map { index, belt in
            let isTop = index < 4
            let column = isTop ? index : index - 4
            let xFraction = CGFloat(column) / 3.0 * 0.8 + 0.1
            return Sprite(
                id: index,
                assetName: belt.assetName,
                xFraction: xFraction,
                yFraction: isTop ? 0.12 : 0.88,
                phase: Double(index) * 0.25
            )
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        FloatingBeltsView()
    }
}
