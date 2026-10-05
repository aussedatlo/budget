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
            TimelineView(.animation(paused: DemoData.pausesAnimations)) { timeline in
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

/// A banknote of the app's currency floating next to what's left of the
/// month, swaying gently. Greyed out when over budget.
struct BanknoteView: View {
    /// Whether some of the income is still left this month.
    var hasLeft = true

    /// 💶 for euros, 💷 pounds, 💴 yen, 💵 for anything else.
    static var note: String {
        switch AppSettings.currencyCode {
        case "EUR": "💶"
        case "GBP": "💷"
        case "JPY": "💴"
        default: "💵"
        }
    }

    var body: some View {
        // Frozen during UI tests so XCTest can wait for the app to be idle
        TimelineView(.animation(paused: DemoData.pausesAnimations)) { timeline in
            GeometryReader { geometry in
                note(time: timeline.date.timeIntervalSinceReferenceDate, width: geometry.size.width)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .saturation(hasLeft ? 1 : 0.2)
        .accessibilityElement()
        .accessibilityLabel("Banknote")
        // Not "banknote": that's the Income tab's symbol, which UI tests find too
        .accessibilityIdentifier("budget-banknote")
    }

    /// Floats up and down every 3 seconds and sways every 4.
    private func note(time: Double, width: CGFloat) -> some View {
        let wave: Double = sin(time * 2 * .pi / 3)
        let sway: Double = sin(time * 2 * .pi / 4) * 6
        return Moji(Self.note, size: width * 0.8)
            .rotationEffect(.degrees(sway))
            .offset(y: width * 0.06 * CGFloat(wave))
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
            TimelineView(.animation(paused: DemoData.pausesAnimations)) { timeline in
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
