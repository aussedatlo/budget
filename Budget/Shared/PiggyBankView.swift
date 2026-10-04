import SwiftUI

/// A piggy bank bouncing gently, with a coin dropping into its slot
/// each time `coins` goes up.
struct PiggyBankView: View {
    /// Goes up when money comes in: a coin drops in.
    var coins = 0

    /// What moves when a coin drops in.
    private struct Drop {
        /// Height of the coin, in the drawing's units (the slot is at 28).
        var coinY: CGFloat = -24
        var coinOpacity: Double = 0
        /// The piggy's happy hop, in the drawing's units (negative is up).
        var hop: CGFloat = 0
    }

    var body: some View {
        KeyframeAnimator(initialValue: Drop(), trigger: coins) { drop in
            // Frozen during UI tests so XCTest can wait for the app to be idle
            TimelineView(.animation(paused: DemoData.isEnabled)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                // 0 on the ground, 1 at the top of a bounce
                let up = CGFloat(abs(sin(time * .pi * 0.9)))
                let squash = pow(1 - up, 6) * 0.06
                GeometryReader { geometry in
                    let scale = geometry.size.width / PiggyDrawing.width
                    ZStack(alignment: .topLeading) {
                        // Shadow on the ground, smaller while up
                        Ellipse()
                            .fill(Theme.ink.opacity(0.08))
                            .frame(width: 70 * scale * (1 - up * 0.2), height: 6 * scale)
                            .position(x: 58 * scale, y: 95 * scale)
                        ZStack(alignment: .topLeading) {
                            // Behind the piggy: it goes out of sight through the slot
                            Circle()
                                .fill(Theme.coin)
                                .overlay(Circle().inset(by: 2 * scale).stroke(Theme.coinEdge, lineWidth: 1.5 * scale))
                                .frame(width: 14 * scale, height: 14 * scale)
                                .position(x: 57 * scale, y: drop.coinY * scale)
                                .opacity(drop.coinOpacity)
                            PiggyDrawing()
                        }
                        .scaleEffect(x: 1 + squash / 2, y: 1 - squash, anchor: .bottom)
                        .offset(y: (drop.hop - up * 5) * scale)
                    }
                }
            }
        } keyframes: { _ in
            KeyframeTrack(\.coinY) {
                LinearKeyframe(-24, duration: 0.01)
                CubicKeyframe(36, duration: 0.45)
                LinearKeyframe(36, duration: 0.3)
            }
            KeyframeTrack(\.coinOpacity) {
                LinearKeyframe(1, duration: 0.01)
                LinearKeyframe(1, duration: 0.42)
                LinearKeyframe(0, duration: 0.05)
            }
            KeyframeTrack(\.hop) {
                LinearKeyframe(0, duration: 0.45)
                SpringKeyframe(-12, duration: 0.15, spring: .snappy)
                SpringKeyframe(0, duration: 0.6, spring: .bouncy)
            }
        }
        .aspectRatio(PiggyDrawing.width / PiggyDrawing.height, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("Piggy bank")
        .accessibilityIdentifier("piggy-bank")
    }
}

/// The piggy bank itself, facing right, drawn in a 120 × 100 box.
struct PiggyDrawing: View {
    static let width: CGFloat = 120
    static let height: CGFloat = 100

    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / Self.width, y: size.height / Self.height)
            let pink = GraphicsContext.Shading.color(Theme.piggy)
            let darkPink = GraphicsContext.Shading.color(Theme.piggyDark)
            let outline = GraphicsContext.Shading.color(Theme.ink.opacity(0.15))

            // Legs
            for x: CGFloat in [32, 46, 70, 84] {
                let leg = Path(roundedRect: CGRect(x: x, y: 70, width: 11, height: 22), cornerRadius: 4)
                context.fill(leg, with: darkPink)
            }
            // Curly tail
            var tail = Path()
            tail.move(to: CGPoint(x: 17, y: 56))
            tail.addQuadCurve(to: CGPoint(x: 6, y: 54), control: CGPoint(x: 10, y: 62))
            tail.addQuadCurve(to: CGPoint(x: 10, y: 46), control: CGPoint(x: 1, y: 46))
            context.stroke(tail, with: darkPink, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            // Body
            let belly = Path(ellipseIn: CGRect(x: 14, y: 26, width: 88, height: 56))
            context.fill(belly, with: pink)
            context.stroke(belly, with: outline, lineWidth: 2)
            // Shine
            context.fill(Path(ellipseIn: CGRect(x: 26, y: 36, width: 8, height: 16)), with: .color(.white.opacity(0.4)))
            // Ear
            var ear = Path()
            ear.move(to: CGPoint(x: 72, y: 32))
            ear.addQuadCurve(to: CGPoint(x: 80, y: 14), control: CGPoint(x: 70, y: 20))
            ear.addQuadCurve(to: CGPoint(x: 90, y: 33), control: CGPoint(x: 90, y: 22))
            ear.closeSubpath()
            context.fill(ear, with: darkPink)
            // Snout and nostrils
            context.fill(Path(ellipseIn: CGRect(x: 95, y: 44, width: 16, height: 20)), with: darkPink)
            for x: CGFloat in [99, 105] {
                context.fill(Path(ellipseIn: CGRect(x: x, y: 51, width: 3, height: 5)),
                             with: .color(Theme.ink.opacity(0.45)))
            }
            // Eye and cheek
            context.fill(Path(ellipseIn: CGRect(x: 83, y: 42, width: 6, height: 6)), with: .color(Theme.ink))
            context.fill(Path(ellipseIn: CGRect(x: 78, y: 55, width: 11, height: 6)),
                         with: .color(Theme.accent.opacity(0.35)))
            // Coin slot
            context.fill(Path(roundedRect: CGRect(x: 46, y: 29, width: 22, height: 4), cornerRadius: 2),
                         with: .color(Theme.ink.opacity(0.55)))
        }
    }
}
