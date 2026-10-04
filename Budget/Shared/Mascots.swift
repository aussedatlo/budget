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
