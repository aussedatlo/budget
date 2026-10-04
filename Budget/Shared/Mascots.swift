import SwiftUI

/// The money bag next to the monthly income: it bounces gently, and a coin
/// drops into it each time `coins` goes up.
struct MoneyBagView: View {
    /// Goes up when money comes in: a coin drops in.
    var coins = 0

    /// What moves when a coin drops in.
    private struct Drop {
        /// Height of the coin's center, as a share of the view's height.
        var coinY: CGFloat = -0.2
        var coinOpacity: Double = 0
        /// The bag's happy hop, as a share of the view's height (negative is up).
        var hop: CGFloat = 0
    }

    var body: some View {
        KeyframeAnimator(initialValue: Drop(), trigger: coins) { drop in
            // Frozen during UI tests so XCTest can wait for the app to be idle
            TimelineView(.animation(paused: DemoData.isEnabled)) { timeline in
                bag(time: timeline.date.timeIntervalSinceReferenceDate, drop: drop)
            }
        } keyframes: { _ in
            KeyframeTrack(\.coinY) {
                LinearKeyframe(-0.2, duration: 0.01)
                CubicKeyframe(0.3, duration: 0.45)
                LinearKeyframe(0.3, duration: 0.3)
            }
            KeyframeTrack(\.coinOpacity) {
                LinearKeyframe(1, duration: 0.01)
                LinearKeyframe(1, duration: 0.4)
                LinearKeyframe(0, duration: 0.08)
            }
            KeyframeTrack(\.hop) {
                LinearKeyframe(0, duration: 0.45)
                SpringKeyframe(-0.1, duration: 0.15, spring: .snappy)
                SpringKeyframe(0, duration: 0.6, spring: .bouncy)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("Money bag")
        .accessibilityIdentifier("money-bag")
    }

    /// The bag at `time`, mid-way through `drop`.
    private func bag(time: Double, drop: Drop) -> some View {
        // 0 on the ground, 1 at the top of a bounce
        let up = CGFloat(abs(sin(time * .pi * 0.9)))
        let squash: CGFloat = pow(1 - up, 6) * 0.06
        return GeometryReader { geometry in
            let side: CGFloat = geometry.size.width
            ZStack {
                // Shadow on the ground, smaller while up
                Ellipse()
                    .fill(Theme.ink.opacity(0.08))
                    .frame(width: side * 0.6 * (1 - up * 0.2), height: side * 0.06)
                    .position(x: side / 2, y: side * 0.94)
                ZStack {
                    // Behind the bag: it goes out of sight through the bag's neck
                    Moji("🪙", size: side * 0.3)
                        .position(x: side / 2, y: side * drop.coinY)
                        .opacity(drop.coinOpacity)
                    Moji("💰", size: side)
                        .position(x: side / 2, y: side / 2)
                }
                .scaleEffect(x: 1 + squash / 2, y: 1 - squash, anchor: .bottom)
                .offset(y: (drop.hop - up * 0.05) * side)
            }
        }
    }
}

/// Banknotes with wings, flying a loop around their box, turning back at
/// each end. They do a somersault each time `flips` goes up.
struct FlyingBanknotesView: View {
    var flips = 0

    var body: some View {
        KeyframeAnimator(initialValue: 0.0, trigger: flips) { spin in
            // Frozen during UI tests so XCTest can wait for the app to be idle
            TimelineView(.animation(paused: DemoData.isEnabled)) { timeline in
                banknotes(time: timeline.date.timeIntervalSinceReferenceDate, spin: spin)
            }
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(-360, duration: 0.8)
                LinearKeyframe(0, duration: 0.01)
            }
        }
        .aspectRatio(1.15, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("Flying banknotes")
        .accessibilityIdentifier("flying-banknotes")
    }

    /// The banknotes where they are at `time`, spun by `spin` degrees.
    private func banknotes(time: Double, spin: Double) -> some View {
        // One figure eight every 7 seconds
        let angle: Double = time * 2 * .pi / 7
        // Faces where it's going, squeezing flat while it turns around
        let turn: Double = min(max(cos(angle) * 4, -1), 1)
        let facing = CGFloat(turn >= 0 ? max(turn, 0.05) : min(turn, -0.05))
        // Nose down while going down
        let tilt: Double = cos(angle * 2) * 10 + spin
        // Wings beating: a quick squeeze up and down
        let flap = CGFloat(1 + sin(time * 2 * .pi * 3) * 0.08)
        let across = CGFloat(sin(angle))
        let upDown = CGFloat(sin(angle * 2))
        return GeometryReader { geometry in
            let width: CGFloat = geometry.size.width
            let height: CGFloat = geometry.size.height
            let side: CGFloat = width * 0.6
            Moji("💸", size: side)
                .scaleEffect(x: 1, y: flap)
                .rotationEffect(.degrees(tilt))
                .scaleEffect(x: facing, y: 1)
                .position(x: width / 2 + (width - side) / 2 * across, y: height / 2 + height * 0.14 * upDown)
        }
    }
}
