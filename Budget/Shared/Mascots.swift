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

/// Banknotes with wings flying a figure 8 tilted across their box,
/// facing where they go.
struct FlyingBanknotesView: View {
    /// Tilt of the figure 8, in radians.
    private static let tilt = -0.45

    var body: some View {
        // Frozen during UI tests so XCTest can wait for the app to be idle
        TimelineView(.animation(paused: DemoData.isEnabled)) { timeline in
            banknotes(time: timeline.date.timeIntervalSinceReferenceDate)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("Flying banknotes")
        .accessibilityIdentifier("flying-banknotes")
    }

    /// Where the 8 is at `angle`, from -1 to 1 on both axes, tilted.
    private static func point(_ angle: Double) -> (x: Double, y: Double) {
        let x = sin(angle)
        let y = sin(angle * 2) * 0.55
        return (x * cos(tilt) - y * sin(tilt), x * sin(tilt) + y * cos(tilt))
    }

    /// The banknotes where they are at `time`.
    private func banknotes(time: Double) -> some View {
        // One figure 8 every 7 seconds
        let angle: Double = time * 2 * .pi / 7
        let here = Self.point(angle)
        let next = Self.point(angle + 0.05)
        let dx: Double = next.x - here.x
        let dy: Double = next.y - here.y
        // Faces where it's going, squeezing flat while it turns around
        // (never thinner than a third, so they don't turn into a sliver)
        let turn: Double = min(max(dx * 60, -1), 1)
        let facing = CGFloat(turn >= 0 ? max(turn, 0.35) : min(turn, -0.35))
        // Nose down while going down
        let slope: Double = dy / max(abs(dx), 0.01)
        let pitch: Double = min(max(slope, -1), 1) * 18
        // Wings beating: a quick squeeze up and down
        let flap = CGFloat(1 + sin(time * 2 * .pi * 3) * 0.08)
        let across = CGFloat(here.x)
        let upDown = CGFloat(here.y)
        return GeometryReader { geometry in
            let width: CGFloat = geometry.size.width
            let height: CGFloat = geometry.size.height
            let side: CGFloat = width * 0.75
            Moji("💸", size: side)
                .scaleEffect(x: 1, y: flap)
                .rotationEffect(.degrees(pitch))
                .scaleEffect(x: facing, y: 1)
                // The loop may reach a little past the box, over the card's padding
                .position(x: width / 2 + width * 0.22 * across,
                          y: height / 2 + height * 0.2 * upDown)
        }
    }
}

/// A seedling next to the Wealth total: it grows when shown, sways in the
/// wind, and springs up each time `pops` goes up.
struct GrowingSeedlingView: View {
    var pops = 0
    @State private var grown = false

    var body: some View {
        KeyframeAnimator(initialValue: 1.0, trigger: pops) { pop in
            // Frozen during UI tests so XCTest can wait for the app to be idle
            TimelineView(.animation(paused: DemoData.isEnabled)) { timeline in
                seedling(time: timeline.date.timeIntervalSinceReferenceDate, pop: pop)
            }
        } keyframes: { _ in
            KeyframeTrack {
                SpringKeyframe(1.35, duration: 0.25, spring: .snappy)
                SpringKeyframe(1, duration: 0.8, spring: .bouncy)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear {
            withAnimation(.spring(duration: 1.4, bounce: 0.35)) { grown = true }
        }
        .onDisappear { grown = false }
        .accessibilityElement()
        .accessibilityLabel("Seedling")
        .accessibilityIdentifier("seedling")
    }

    /// The seedling at `time`, `pop` times its size.
    private func seedling(time: Double, pop: Double) -> some View {
        let sway: Double = sin(time * 2 * .pi / 3.2) * 6
        let breath = CGFloat(1 + sin(time * 2 * .pi / 4) * 0.03)
        let size = CGFloat(grown ? pop : 0.3) * breath
        return GeometryReader { geometry in
            let side: CGFloat = geometry.size.width
            ZStack(alignment: .bottom) {
                // A little mound of soil
                Ellipse()
                    .fill(Theme.ink.opacity(0.08))
                    .frame(width: side * 0.6, height: side * 0.08)
                Moji("🌱", size: side * 0.85)
                    .scaleEffect(size, anchor: .bottom)
                    .rotationEffect(.degrees(sway), anchor: .bottom)
                    .padding(.bottom, side * 0.03)
            }
            .frame(width: side, height: side, alignment: .bottom)
        }
    }
}
