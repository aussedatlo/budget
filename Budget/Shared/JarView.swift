import SwiftUI

/// A jar that fills up with what's left of the month, with the
/// percentage written on it.
struct JarView: View {
    /// 0...1, how full the jar is.
    var level: Double

    var body: some View {
        // Frozen during UI tests so XCTest can wait for the app to be idle
        TimelineView(.animation(paused: DemoData.isEnabled)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { geometry in
                let size = geometry.size
                ZStack(alignment: .top) {
                    // Glass
                    JarShape()
                        .fill(Theme.background)
                    // Content
                    WaveShape(level: level, phase: time * 1.2, amplitude: level > 0 ? 2.5 : 0)
                        .fill(Theme.accent.opacity(0.55))
                        .clipShape(JarShape())
                        .animation(.spring(duration: 1.2, bounce: 0.15), value: level)
                    // Shine
                    Capsule()
                        .fill(.white.opacity(0.35))
                        .frame(width: size.width * 0.06, height: size.height * 0.3)
                        .offset(x: -size.width * 0.3, y: size.height * 0.4)
                    JarShape()
                        .stroke(Theme.ink.opacity(0.15), lineWidth: 2)
                    // Lid
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Theme.ink.opacity(0.75))
                        .frame(width: size.width * 0.68, height: size.height * 0.07)
                        .offset(y: -size.height * 0.04)
                    Text(level.formatted(.percent.precision(.fractionLength(0))))
                        .font(.system(size: size.width * 0.2, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText(value: level))
                        .animation(.snappy, value: level)
                        .frame(maxWidth: .infinity)
                        .offset(y: size.height * 0.5)
                }
            }
        }
        .aspectRatio(0.82, contentMode: .fit)
        .accessibilityHidden(true)
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
