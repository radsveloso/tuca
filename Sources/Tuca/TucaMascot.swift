import SwiftUI

/// O Tuca: um tucano desenhado em código que espia pelo notch.
struct TucaMascot: View {
    var mood: Mood = .idle

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in draw(ctx, size, t) }
        }
    }

    private func draw(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double) {
        let h = min(size.height, size.width / 1.6)
        let ox = (size.width - h * 1.6) / 2
        let oy = (size.height - h) / 2
        var bob: CGFloat = 0
        switch mood {
        case .working: bob = CGFloat(sin(t * 6)) * 0.035
        case .attention: bob = CGFloat(sin(t * 16)) * 0.03
        case .done: bob = CGFloat(max(0, sin(t * 3))) * -0.05
        case .idle: bob = 0
        }
        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + x * h, y: oy + (y + bob) * h) }
        func circle(_ c: CGPoint, _ r: CGFloat, sy: CGFloat = 1) -> Path {
            Path(ellipseIn: CGRect(x: c.x - r * h, y: c.y - r * h * sy, width: 2 * r * h, height: 2 * r * h * sy))
        }

        // cabeça
        ctx.fill(circle(P(0.34, 0.55), 0.36), with: .color(Color(white: 0.17)))
        // papo branco
        ctx.fill(circle(P(0.42, 0.72), 0.19), with: .color(Color(white: 0.96)))

        // bico
        var beak = Path()
        beak.move(to: P(0.54, 0.30))
        beak.addQuadCurve(to: P(1.56, 0.60), control: P(1.18, 0.10))
        beak.addQuadCurve(to: P(0.58, 0.82), control: P(1.12, 0.88))
        beak.closeSubpath()
        ctx.fill(beak, with: .linearGradient(
            Gradient(colors: [Color(red: 1, green: 0.88, blue: 0.28),
                              Color(red: 1, green: 0.56, blue: 0.12),
                              Color(red: 0.93, green: 0.24, blue: 0.16)]),
            startPoint: P(0.6, 0.5), endPoint: P(1.56, 0.6)))
        var line = Path()
        line.move(to: P(0.6, 0.58))
        line.addQuadCurve(to: P(1.5, 0.61), control: P(1.05, 0.62))
        ctx.stroke(line, with: .color(.black.opacity(0.45)), lineWidth: max(0.8, h * 0.035))

        // olho com piscada
        let cycle = t.truncatingRemainder(dividingBy: 4.3)
        var open: CGFloat = cycle < 0.13 ? 0.12 : 1
        if mood == .attention { open = 1 }
        let ring: CGFloat = mood == .attention ? 0.15 : 0.12
        ctx.fill(circle(P(0.34, 0.42), ring, sy: open), with: .color(Color(red: 0.3, green: 0.68, blue: 1)))
        ctx.fill(circle(P(0.355, 0.42), ring * 0.5, sy: open), with: .color(.black))
        if open > 0.5 {
            ctx.fill(circle(P(0.33, 0.39), 0.025), with: .color(.white))
        }
    }
}
