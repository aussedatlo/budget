import SwiftUI

/// A little jar with a face. It fills up with what's left of the month
/// and its mood follows how full it is.
struct JarView: View {
    /// 0...1, how full the jar is.
    var level: Double

    enum Mood { case happy, content, worried, sad }

    var mood: Mood {
        switch level {
        case 0.5...: .happy
        case 0.2..<0.5: .content
        case 0.0001..<0.2: .worried
        default: .sad
        }
    }

    var body: some View {
        // Frozen during UI tests so XCTest can wait for the app to be idle
        TimelineView(.animation(paused: DemoData.isEnabled)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { geometry in
                let size = geometry.size
                ZStack(alignment: .top) {
                    // Glass
                    JarShape()
                        .fill(Theme.card.opacity(0.85))
                    // Content
                    WaveShape(level: level, phase: time * 2.2, amplitude: level > 0 ? 5 : 0)
                        .fill(
                            LinearGradient(
                                colors: [Color(light: 0xFFB3CF, dark: 0xD9789E), Color(light: 0xFFCBA4, dark: 0xD99A6E)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .clipShape(JarShape())
                        .animation(.spring(duration: 1.2, bounce: 0.35), value: level)
                    // Shine
                    Capsule()
                        .fill(.white.opacity(0.45))
                        .frame(width: size.width * 0.07, height: size.height * 0.35)
                        .offset(x: -size.width * 0.3, y: size.height * 0.38)
                    JarShape()
                        .stroke(Theme.ink.opacity(0.18), lineWidth: 3)
                    // Lid
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Theme.accent)
                        .frame(width: size.width * 0.68, height: size.height * 0.09)
                        .offset(y: -size.height * 0.05)
                    face(time: time, size: size)
                        .offset(y: size.height * 0.48)
                    if mood == .happy {
                        sparkles(time: time, size: size)
                    }
                }
            }
        }
        .aspectRatio(0.82, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func face(time: Double, size: CGSize) -> some View {
        // Blink for a moment every few seconds
        let blinking = time.truncatingRemainder(dividingBy: 4.2) < 0.14
        let eye = size.width * 0.075
        return VStack(spacing: size.height * 0.03) {
            HStack(spacing: size.width * 0.22) {
                ForEach(0..<2, id: \.self) { _ in
                    Capsule()
                        .fill(Theme.ink)
                        .frame(width: eye, height: blinking ? eye * 0.2 : eye)
                }
            }
            ZStack {
                HStack(spacing: size.width * 0.38) {
                    ForEach(0..<2, id: \.self) { _ in
                        Circle().fill(Theme.accent.opacity(0.35)).frame(width: eye * 1.4)
                    }
                }
                MouthShape(curve: mouthCurve)
                    .stroke(Theme.ink, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: size.width * 0.2, height: size.height * 0.06)
                    .animation(.bouncy, value: mouthCurve)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var mouthCurve: Double {
        switch mood {
        case .happy: 1
        case .content: 0.5
        case .worried: 0
        case .sad: -0.8
        }
    }

    private func sparkles(time: Double, size: CGSize) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                let bob = sin(time * 2 + Double(i) * 2) * 4
                Text(["✨", "💖", "✨"][i])
                    .font(.system(size: size.width * (i == 1 ? 0.14 : 0.11)))
                    .offset(x: CGFloat(i - 1) * size.width * 0.42, y: -size.height * 0.12 + bob)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct JarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let neck = w * 0.18
        let neckBottom = h * 0.12
        let shoulder = h * 0.26
        let radius = w * 0.24
        var path = Path()
        path.move(to: CGPoint(x: neck, y: 0))
        path.addLine(to: CGPoint(x: w - neck, y: 0))
        path.addLine(to: CGPoint(x: w - neck, y: neckBottom))
        path.addQuadCurve(to: CGPoint(x: w, y: shoulder), control: CGPoint(x: w, y: neckBottom))
        path.addLine(to: CGPoint(x: w, y: h - radius))
        path.addQuadCurve(to: CGPoint(x: w - radius, y: h), control: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: radius, y: h))
        path.addQuadCurve(to: CGPoint(x: 0, y: h - radius), control: CGPoint(x: 0, y: h))
        path.addLine(to: CGPoint(x: 0, y: shoulder))
        path.addQuadCurve(to: CGPoint(x: neck, y: neckBottom), control: CGPoint(x: 0, y: neckBottom))
        path.closeSubpath()
        return path.offsetBy(dx: rect.minX, dy: rect.minY)
    }
}

/// Liquid with a gently moving surface.
struct WaveShape: Shape {
    var level: Double
    var phase: Double
    var amplitude: CGFloat

    var animatableData: Double {
        get { level }
        set { level = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let clamped = min(max(level, 0), 1)
        // Leave some room under the lid when full
        let surface = rect.height * (1 - CGFloat(clamped) * 0.86)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: surface))
        for x in stride(from: 0, through: rect.width, by: 2) {
            let angle = Double(x / rect.width) * 2 * .pi * 1.2 + phase
            path.addLine(to: CGPoint(x: x, y: surface + CGFloat(sin(angle)) * amplitude))
        }
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

/// A smile (curve > 0), a flat line (0) or a frown (< 0).
struct MouthShape: Shape {
    var curve: Double

    var animatableData: Double {
        get { curve }
        set { curve = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control: CGPoint(x: rect.midX, y: rect.midY + rect.height * CGFloat(curve))
        )
        return path
    }
}
