import SwiftUI

/// Emoji confetti falling over the screen each time `trigger` changes.
struct ConfettiView: View {
    let trigger: Int

    private struct Particle {
        let emoji = ["🎉", "💖", "✨", "🌸", "🪙", "💎"].randomElement()!
        let x = Double.random(in: 0...1)
        let delay = Double.random(in: 0...0.6)
        let speed = Double.random(in: 0.35...0.6)
        let wobble = Double.random(in: 2...5)
        let spin = Double.random(in: -240...240)
        let size = Double.random(in: 16...28)
    }

    private static let duration = 3.2
    private static let images: [String: Image] = Dictionary(
        uniqueKeysWithValues: ["🎉", "💖", "✨", "🌸", "🪙", "💎"].compactMap { emoji in
            OpenMoji.image(for: emoji).map { (emoji, $0) }
        }
    )

    @State private var particles = (0..<45).map { _ in Particle() }
    @State private var start: Date?

    var body: some View {
        TimelineView(.animation(paused: start == nil)) { timeline in
            Canvas { context, size in
                guard let start else { return }
                let elapsed = timeline.date.timeIntervalSince(start)
                for particle in particles {
                    let t = elapsed - particle.delay
                    guard t > 0 else { continue }
                    var copy = context
                    copy.opacity = max(0, 1 - t / (Self.duration - particle.delay))
                    let x = particle.x * size.width + sin(t * particle.wobble) * 18
                    let y = -30 + t * particle.speed * size.height
                    copy.translateBy(x: x, y: y)
                    copy.rotate(by: .degrees(t * particle.spin))
                    if let image = Self.images[particle.emoji] {
                        let side = particle.size * 1.2
                        copy.draw(image, in: CGRect(x: -side / 2, y: -side / 2, width: side, height: side))
                    } else {
                        copy.draw(Text(particle.emoji).font(.system(size: particle.size)), at: .zero)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: trigger) {
            particles = (0..<45).map { _ in Particle() }
            start = .now
            Task {
                try? await Task.sleep(for: .seconds(Self.duration))
                start = nil
            }
        }
    }
}
