import AppKit
import SwiftUI
import TucaCore

// MARK: - Efeitos e entrada compartilhada

/// Estado leve que o mascote lê a cada quadro, sem invalidar o SwiftUI
/// (posição do mouse, clique, arraste e recebimento de arquivo).
final class TucaFX {
    static let shared = TucaFX()

    var mouse: CGPoint = .zero
    var anchor: CGPoint = .zero
    var clickAt: Date = .distantPast
    var receivedAt: Date = .distantPast
    var dragHover = false
    /// Fornecido pelo app: monta as entradas do resolvedor a partir das sessões, do chat e do notch.
    var inputs: ((Date) -> TucaInputs)?

    private var animators: [String: PoseAnimator] = [:]

    func animator(_ slot: String) -> PoseAnimator {
        if let a = animators[slot] { return a }
        let a = PoseAnimator()
        animators[slot] = a
        return a
    }

    func state(at now: Date) -> TucaVisualState {
        TucaStateResolver.resolve(inputs?(now) ?? TucaInputs(now: now))
    }

    func interaction(at now: Date) -> TucaInteraction {
        if now.timeIntervalSince(receivedAt) < 1.2 { return .receivingFile }
        if dragHover { return .dragHover }
        if now.timeIntervalSince(clickAt) < 0.7 { return .clickReaction }
        return .none
    }

    var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
}

// MARK: - Pose

/// Parâmetros de pose. Todo estado é a mesma figura com valores diferentes, então não há troca de desenho.
struct TucaPose {
    var tilt: CGFloat = 0        // rad; positivo inclina o bico para baixo
    var headY: CGFloat = 0
    var lookX: CGFloat = 0.35    // -1...1
    var lookY: CGFloat = 0
    var track: CGFloat = 0.6     // peso do olhar seguindo o cursor
    var eyeOpen: CGFloat = 1
    var iris: CGFloat = 1
    var worry: CGFloat = 0
    var beak: CGFloat = 0        // abertura 0...1
    var wing: CGFloat = 0        // asa levantada 0...1
    var crouch: CGFloat = 0

    static func lerp(_ a: TucaPose, _ b: TucaPose, _ t: CGFloat) -> TucaPose {
        func m(_ x: CGFloat, _ y: CGFloat) -> CGFloat { x + (y - x) * t }
        return TucaPose(tilt: m(a.tilt, b.tilt), headY: m(a.headY, b.headY), lookX: m(a.lookX, b.lookX),
                        lookY: m(a.lookY, b.lookY), track: m(a.track, b.track), eyeOpen: m(a.eyeOpen, b.eyeOpen),
                        iris: m(a.iris, b.iris), worry: m(a.worry, b.worry), beak: m(a.beak, b.beak),
                        wing: m(a.wing, b.wing), crouch: m(a.crouch, b.crouch))
    }

    static func target(_ s: TucaVisualState, _ i: TucaInteraction) -> TucaPose {
        var p = TucaPose()
        switch s {
        case .idle: break
        case .watching: p.lookX = 0.5; p.track = 1; p.iris = 1.05
        case .thinking: p.tilt = -0.12; p.lookX = -0.15; p.lookY = -0.85; p.track = 0.15; p.eyeOpen = 0.92
        case .working: p.tilt = 0.05; p.lookX = 0.7; p.lookY = 0.35; p.track = 0.15
        case .reading: p.tilt = 0.16; p.headY = 2; p.lookX = 0.45; p.lookY = 0.9; p.track = 0.1; p.eyeOpen = 0.85
        case .writing: p.tilt = 0.12; p.headY = 1.5; p.lookX = 0.85; p.lookY = 0.7; p.track = 0.1
        case .running: p.tilt = -0.03; p.lookX = 1; p.track = 0.1; p.iris = 0.95; p.wing = 0.3
        case .waiting: p.lookX = 0.2; p.lookY = 0.1; p.track = 0.4; p.eyeOpen = 0.9
        case .needsAttention: p.tilt = -0.06; p.iris = 1.15; p.beak = 0.25; p.lookX = 0.15; p.lookY = -0.1; p.wing = 0.35
        case .success: p.tilt = -0.14; p.beak = 0.5; p.wing = 1; p.lookX = 0.3; p.lookY = -0.3; p.track = 0
        case .error: p.tilt = 0.14; p.headY = 2.5; p.eyeOpen = 0.62; p.worry = 1; p.track = 0; p.lookX = 0.2; p.lookY = 0.6
        case .sleeping: p.tilt = 0.3; p.headY = 6; p.eyeOpen = 0; p.track = 0; p.crouch = 1
        }
        switch i {
        case .dragHover: p.iris = 1.15; p.beak = max(p.beak, 0.35); p.track = 1; p.eyeOpen = 1; p.worry = 0; p.crouch = 0
        case .receivingFile: p.eyeOpen = 1; p.worry = 0; p.crouch = 0; p.track = 0; p.lookX = 0.9; p.lookY = -0.2
        default: break
        }
        return p
    }
}

/// Interpola de uma pose para outra com easing quando o estado muda (sem cortes secos).
final class PoseAnimator {
    private var from = TucaPose()
    private var to = TucaPose()
    private var key = ""
    private(set) var changedAt: Double = 0

    func pose(target: TucaPose, key: String, t: Double, duration: Double) -> TucaPose {
        if self.key.isEmpty {
            from = target; to = target; self.key = key; changedAt = t
        } else if key != self.key {
            from = current(t, duration); to = target; self.key = key; changedAt = t
        } else {
            to = target
        }
        return current(t, duration)
    }

    private func current(_ t: Double, _ d: Double) -> TucaPose {
        let p = d <= 0 ? 1 : min(1, max(0, (t - changedAt) / d))
        let e = 1 - pow(1 - p, 3)
        return TucaPose.lerp(from, to, CGFloat(e))
    }
}

// MARK: - View

/// O Tuca. Um único personagem vetorial em camadas; o estado vem do resolvedor do TucaCore.
struct TucaMascot: View {
    var slot: String
    var forced: TucaVisualState? = nil
    var forcedInteraction: TucaInteraction? = nil

    var body: some View {
        let fx = TucaFX.shared
        let reduce = fx.reduceMotion
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { tl in
            let now = tl.date
            let state = forced ?? fx.state(at: now)
            let inter = forcedInteraction ?? fx.interaction(at: now)
            let t = now.timeIntervalSinceReferenceDate
            let anim = fx.animator(slot)
            let pose = anim.pose(target: TucaPose.target(state, inter), key: "\(state)|\(inter)",
                                 t: t, duration: reduce ? 0 : 0.38)
            let since = t - anim.changedAt
            let look = Self.cursorLook(fx)
            Canvas { ctx, size in
                TucaRenderer.draw(ctx, size: size, t: t, since: since, state: state, interaction: inter,
                                  pose: pose, cursor: look, fx: fx, reduce: reduce)
            }
            .accessibilityElement()
            .accessibilityLabel("Tuca, \(state.label)")
        }
    }

    private static func cursorLook(_ fx: TucaFX) -> CGPoint {
        let dx = fx.mouse.x - fx.anchor.x
        let dy = fx.mouse.y - fx.anchor.y
        func clamp(_ v: CGFloat) -> CGFloat { max(-1, min(1, v)) }
        return CGPoint(x: clamp(dx / 350), y: clamp(-dy / 220))
    }
}

/// Rótulo de estado (texto + símbolo), para não depender só de cor.
struct TucaStateLabel: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { tl in
            let s = TucaFX.shared.state(at: tl.date)
            HStack(spacing: 4) {
                Image(systemName: s.symbol).font(.system(size: 10, weight: .semibold))
                Text(s.label).font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(s.tint)
            .accessibilityElement(children: .combine)
        }
    }
}

extension TucaVisualState {
    var symbol: String {
        switch self {
        case .idle: "circle"
        case .watching: "eye.fill"
        case .thinking: "ellipsis.bubble.fill"
        case .working: "gearshape.fill"
        case .reading: "book.fill"
        case .writing: "pencil"
        case .running: "terminal.fill"
        case .waiting: "hourglass"
        case .needsAttention: "exclamationmark.circle.fill"
        case .success: "checkmark.circle.fill"
        case .error: "xmark.octagon.fill"
        case .sleeping: "moon.zzz.fill"
        }
    }

    var tint: Color {
        switch self {
        case .needsAttention, .error: Color(red: 1, green: 0.36, blue: 0.32)
        case .success: Color(red: 0.32, green: 0.86, blue: 0.52)
        case .running, .writing, .reading, .working: Color(red: 1, green: 0.6, blue: 0.2)
        case .thinking: TucaPalette.eyeColor
        default: Color.secondary
        }
    }
}

// MARK: - Paleta aprovada

enum TucaPalette {
    static let beak = Color(red: 1.0, green: 0.541, blue: 0.0)          // #FF8A00
    static let beakLight = Color(red: 1.0, green: 0.76, blue: 0.24)
    static let accent = Color(red: 1.0, green: 0.302, blue: 0.0)        // #FF4D00
    static let eyeColor = Color(red: 0.082, green: 0.651, blue: 1.0)    // #15A6FF
    static let face = Color(red: 0.969, green: 0.969, blue: 0.969)      // #F7F7F7
    static let body = Color(red: 0.118, green: 0.125, blue: 0.157)
    static let bodyLight = Color(red: 0.29, green: 0.31, blue: 0.36)
    static let bodyDark = Color(red: 0.07, green: 0.075, blue: 0.094)
    static let tip = Color(red: 0.07, green: 0.075, blue: 0.09)
    static let line = Color(red: 0.05, green: 0.055, blue: 0.07)
}

// MARK: - Desenho

/// Desenha o Tuca numa caixa de 140 x 100 unidades, escalada para o tamanho disponível.
enum TucaRenderer {
    static func draw(_ base: GraphicsContext, size: CGSize, t: Double, since: Double,
                     state: TucaVisualState, interaction: TucaInteraction, pose p0: TucaPose,
                     cursor: CGPoint, fx: TucaFX, reduce: Bool) {
        let s = min(size.width / 140, size.height / 100)
        guard s > 0 else { return }
        let px = s * 100   // altura efetiva em pontos, para decidir o nível de detalhe
        var ctx = base
        ctx.translateBy(x: (size.width - 140 * s) / 2, y: (size.height - 100 * s) / 2)
        ctx.scaleBy(x: s, y: s)

        var p = p0
        let motion: CGFloat = reduce ? 0 : 1

        // Piscada com intervalo pseudoaleatório (às vezes dupla).
        let blink = reduce ? 0 : blinkAmount(t)
        if state != .sleeping { p.eyeOpen *= (1 - blink) }

        // Olhar: mistura o olhar do estado com o cursor (limitado e sutil).
        let track = p.track * motion
        let lookX = p.lookX + (cursor.x - p.lookX) * track
        let lookY = p.lookY + (cursor.y - p.lookY) * track
        p.tilt += lookY * 0.04 * track

        // Movimento procedural por estado.
        let breathe = CGFloat(sin(t * 2 * .pi * 0.25)) * motion
        var bodyY: CGFloat = 0
        var squash: CGFloat = 1
        let e = CGFloat(since)
        switch state {
        case .running: p.headY += CGFloat(sin(t * 16)) * 0.9 * motion
        case .writing: p.tilt += CGFloat(max(0, sin(t * 7))) * 0.035 * motion
        case .working: p.headY += CGFloat(sin(t * 5)) * 0.5 * motion
        case .thinking: p.tilt += CGFloat(sin(t * 1.5)) * 0.02 * motion
        case .waiting: p.tilt += CGFloat(sin(t * 0.9)) * 0.025 * motion
        case .needsAttention: squash = 1 + CGFloat(sin(t * 6)) * 0.025 * motion
        case .success:
            if e < 0.9 { bodyY -= 7 * CGFloat(sin(.pi * Double(e) / 0.9)) * motion }
        case .error:
            if e < 0.6 { p.tilt += 0.05 * CGFloat(sin(Double(e) * 40)) * (1 - e / 0.6) * motion }
        default: break
        }
        var receiveProgress: CGFloat = -1
        switch interaction {
        case .clickReaction:
            let c = CGFloat(Date().timeIntervalSince(fx.clickAt))
            squash *= 1 - 0.08 * CGFloat(sin(.pi * Double(min(c, 0.7)) / 0.7)) * motion
            p.iris = max(p.iris, 1.12)
        case .receivingFile:
            let r = CGFloat(Date().timeIntervalSince(fx.receivedAt))
            receiveProgress = r
            p.beak = r < 0.6 ? 0.9 * CGFloat(sin(.pi * Double(r) / 0.6)) : 0
            if r > 0.6 && r < 1.0 { p.headY += 2 * CGFloat(sin(.pi * Double(r - 0.6) / 0.4)) * motion }
        default: break
        }

        // Postura geral (pulo e compressão a partir dos pés).
        ctx.translateBy(x: 0, y: bodyY)
        if squash != 1 {
            ctx.translateBy(x: 70, y: 100)
            ctx.scaleBy(x: 2 - squash, y: squash)
            ctx.translateBy(x: -70, y: -100)
        }

        // Linhas de velocidade (executando) e detalhes só em tamanhos maiores.
        if state == .running && px >= 30 && !reduce { speedLines(ctx, t: t) }

        // Corpo
        var body = ctx
        body.translateBy(x: 0, y: p.crouch * 8)
        body.translateBy(x: 42, y: 100)
        body.scaleBy(x: 1, y: 1 + 0.018 * breathe)
        body.translateBy(x: -42, y: -100)
        drawBody(body, p: p, detailed: px >= 26)

        // Cabeça
        var head = ctx
        head.translateBy(x: 0, y: p.headY - 0.6 * breathe + p.crouch * 4)
        head.translateBy(x: 46, y: 74)
        head.rotate(by: .radians(Double(p.tilt)))
        head.translateBy(x: -46, y: -74)
        drawHead(head, p: p, lookX: lookX, lookY: lookY, detailed: px >= 26)

        // Acessórios de estado (forma, não só cor).
        if px >= 30 {
            switch state {
            case .thinking: thinkingDots(ctx, t: t, reduce: reduce)
            case .needsAttention: attentionMarks(ctx, t: t, reduce: reduce)
            case .success: if e < 2.5 { sparkles(ctx, e: e) }
            case .sleeping: zzz(ctx, t: t, reduce: reduce)
            default: break
            }
            if interaction == .clickReaction { attentionMarks(ctx, t: t, reduce: true) }
        }
        if receiveProgress >= 0 && receiveProgress < 0.6 && px >= 40 { incomingFile(ctx, r: receiveProgress) }
    }

    // MARK: Partes

    private static func drawBody(_ c: GraphicsContext, p: TucaPose, detailed: Bool) {
        // Penas da cauda: o acento quente aparece só aqui, como na prancha aprovada.
        if detailed {
            var tail = Path()
            tail.addEllipse(in: CGRect(x: 4, y: 96, width: 22, height: 9))
            c.fill(tail.applying(rotation(-0.45, around: CGPoint(x: 15, y: 100))), with: .linearGradient(
                Gradient(colors: [TucaPalette.accent, TucaPalette.beak]),
                startPoint: CGPoint(x: 4, y: 100), endPoint: CGPoint(x: 24, y: 100)))
        }
        let bodyRect = CGRect(x: 14, y: 64, width: 60, height: 64)
        c.fill(Path(ellipseIn: bodyRect), with: .linearGradient(
            Gradient(colors: [TucaPalette.bodyLight, TucaPalette.body, TucaPalette.bodyDark]),
            startPoint: CGPoint(x: 30, y: 70), endPoint: CGPoint(x: 44, y: 110)))
        // Peito branco
        c.fill(Path(ellipseIn: CGRect(x: 38, y: 62, width: 34, height: 56)), with: .linearGradient(
            Gradient(colors: [TucaPalette.face, TucaPalette.face, Color(white: 0.84)]),
            startPoint: CGPoint(x: 55, y: 62), endPoint: CGPoint(x: 55, y: 118)))
        // Asa (levanta em sucesso e atenção)
        var wing = c
        wing.translateBy(x: 30, y: 76)
        wing.rotate(by: .radians(Double(0.3 + 1.15 * p.wing)))
        var wingPath = Path()
        wingPath.move(to: CGPoint(x: 0, y: -4))
        wingPath.addQuadCurve(to: CGPoint(x: -4, y: 34), control: CGPoint(x: 14, y: 12))
        wingPath.addQuadCurve(to: CGPoint(x: 0, y: -4), control: CGPoint(x: -14, y: 10))
        wing.fill(wingPath, with: .linearGradient(
            Gradient(colors: [TucaPalette.bodyLight, TucaPalette.body, TucaPalette.bodyDark]),
            startPoint: CGPoint(x: 0, y: -4), endPoint: CGPoint(x: 0, y: 34)))
        if detailed {
            for k in [0.35, 0.65] {
                var f = Path()
                f.move(to: CGPoint(x: -7, y: 34 * k))
                f.addQuadCurve(to: CGPoint(x: 6, y: 34 * k + 5), control: CGPoint(x: 0, y: 34 * k + 4))
                wing.stroke(f, with: .color(.white.opacity(0.07)), lineWidth: 1)
            }
        }
    }

    private static func drawHead(_ c: GraphicsContext, p: TucaPose, lookX: CGFloat, lookY: CGFloat, detailed: Bool) {
        let headCenter = CGPoint(x: 44, y: 46)
        let headR: CGFloat = 33
        let headPath = Path(ellipseIn: CGRect(x: headCenter.x - headR, y: headCenter.y - headR, width: 2 * headR, height: 2 * headR))

        // Topete
        if detailed {
            for (x, y, w, h, a) in [(20.0, 12.0, 12.0, 18.0, -0.6), (28.0, 8.0, 11.0, 18.0, -0.3), (36.0, 8.0, 10.0, 16.0, 0.0)] {
                let r = CGRect(x: x, y: y, width: w, height: h)
                c.fill(Path(ellipseIn: r).applying(rotation(CGFloat(a), around: CGPoint(x: r.midX, y: r.maxY))),
                       with: .color(TucaPalette.body))
            }
        }
        // Cabeça escura com luz de topo
        c.fill(headPath, with: .radialGradient(
            Gradient(stops: [.init(color: TucaPalette.bodyLight, location: 0),
                             .init(color: TucaPalette.body, location: 0.5),
                             .init(color: TucaPalette.bodyDark, location: 1)]),
            center: CGPoint(x: 32, y: 24), startRadius: 0, endRadius: 52))
        // Rosto branco, recortado pela cabeça
        c.drawLayer { l in
            l.clip(to: headPath)
            l.fill(Path(ellipseIn: CGRect(x: 34, y: 30, width: 46, height: 52)), with: .linearGradient(
                Gradient(colors: [.white, TucaPalette.face, Color(white: 0.88)]),
                startPoint: CGPoint(x: 56, y: 30), endPoint: CGPoint(x: 56, y: 82)))
        }
        // Contorno sutil para a silhueta não sumir no preto do notch
        c.stroke(headPath, with: .color(.white.opacity(0.08)), lineWidth: 1)

        drawBeak(c, open: p.beak, detailed: detailed)
        drawEye(c, p: p, lookX: lookX, lookY: lookY, detailed: detailed)
    }

    private static func drawEye(_ c: GraphicsContext, p: TucaPose, lookX: CGFloat, lookY: CGFloat, detailed: Bool) {
        let E = CGPoint(x: 57, y: 45)
        let r: CGFloat = 12.5
        let sclera = Path(ellipseIn: CGRect(x: E.x - r, y: E.y - r, width: 2 * r, height: 2 * r))
        c.fill(sclera, with: .color(.white))
        c.drawLayer { l in
            l.clip(to: sclera)
            let ir = min(11.8, 10.2 * p.iris)
            let ic = CGPoint(x: E.x + lookX * 2.2, y: E.y + lookY * 2.2)
            l.fill(Path(ellipseIn: CGRect(x: ic.x - ir, y: ic.y - ir, width: 2 * ir, height: 2 * ir)), with: .radialGradient(
                Gradient(stops: [.init(color: Color(red: 0.6, green: 0.88, blue: 1), location: 0),
                                 .init(color: TucaPalette.eyeColor, location: 0.55),
                                 .init(color: Color(red: 0.03, green: 0.33, blue: 0.62), location: 1)]),
                center: CGPoint(x: ic.x - 3, y: ic.y - 4), startRadius: 0, endRadius: ir * 1.3))
            let pr: CGFloat = 5.4
            let pc = CGPoint(x: ic.x + lookX * 0.8, y: ic.y + lookY * 0.8)
            l.fill(Path(ellipseIn: CGRect(x: pc.x - pr, y: pc.y - pr, width: 2 * pr, height: 2 * pr)), with: .color(.black))
            l.fill(Path(ellipseIn: CGRect(x: ic.x - 3.2 - 2.9, y: ic.y - 3.6 - 2.9, width: 5.8, height: 5.8)), with: .color(.white))
            if detailed {
                l.fill(Path(ellipseIn: CGRect(x: ic.x + 3 - 1.3, y: ic.y + 3.2 - 1.3, width: 2.6, height: 2.6)), with: .color(.white.opacity(0.85)))
            }
            // Pálpebra superior (piscada, sono, preocupação), na cor do rosto
            let open = max(0, min(1, p.eyeOpen))
            if open < 0.999 || p.worry > 0 {
                let lidY = E.y - r + (1 - open) * 2 * r
                let slant = p.worry * 3.5
                var lid = Path()
                lid.move(to: CGPoint(x: E.x - r - 2, y: E.y - r - 2))
                lid.addLine(to: CGPoint(x: E.x + r + 2, y: E.y - r - 2))
                lid.addLine(to: CGPoint(x: E.x + r + 2, y: lidY - slant))
                lid.addLine(to: CGPoint(x: E.x - r - 2, y: lidY + slant))
                lid.closeSubpath()
                l.fill(lid, with: .color(TucaPalette.face))
                var edge = Path()
                edge.move(to: CGPoint(x: E.x - r - 2, y: lidY + slant))
                edge.addLine(to: CGPoint(x: E.x + r + 2, y: lidY - slant))
                l.stroke(edge, with: .color(TucaPalette.line), lineWidth: 1.6)
            }
        }
        if p.eyeOpen < 0.08 {
            // Olho fechado: arco escuro sobre o rosto
            var arc = Path()
            arc.move(to: CGPoint(x: E.x - 9, y: E.y))
            arc.addQuadCurve(to: CGPoint(x: E.x + 9, y: E.y), control: CGPoint(x: E.x, y: E.y + 6))
            c.fill(sclera, with: .color(TucaPalette.face))
            c.stroke(arc, with: .color(TucaPalette.line), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        } else {
            c.stroke(sclera, with: .color(TucaPalette.line), lineWidth: 1.2)
        }
    }

    private static func drawBeak(_ c: GraphicsContext, open: CGFloat, detailed: Bool) {
        let hinge = CGPoint(x: 68, y: 55)
        let angle = 0.32 * open

        var upper = Path()
        upper.move(to: CGPoint(x: 61, y: 22))
        upper.addCurve(to: CGPoint(x: 138, y: 72), control1: CGPoint(x: 92, y: 2), control2: CGPoint(x: 128, y: 22))
        upper.addQuadCurve(to: CGPoint(x: 70, y: 58), control: CGPoint(x: 112, y: 62))
        upper.addQuadCurve(to: CGPoint(x: 61, y: 22), control: CGPoint(x: 54, y: 40))

        var lower = Path()
        lower.move(to: CGPoint(x: 68, y: 56))
        lower.addQuadCurve(to: CGPoint(x: 132, y: 71), control: CGPoint(x: 110, y: 62))
        lower.addQuadCurve(to: CGPoint(x: 74, y: 70), control: CGPoint(x: 106, y: 81))
        lower.closeSubpath()
        let rot = rotation(angle, around: hinge)
        let lowerRot = lower.applying(rot)

        // Interior da boca quando aberto
        if open > 0.02 {
            var mouth = Path()
            mouth.move(to: hinge)
            mouth.addLine(to: CGPoint(x: 100, y: 62))
            mouth.addLine(to: CGPoint(x: 128, y: 69))
            mouth.addLine(to: CGPoint(x: 128, y: 69).applying(rot))
            mouth.addLine(to: CGPoint(x: 100, y: 62).applying(rot))
            mouth.closeSubpath()
            c.fill(mouth, with: .color(Color(red: 0.29, green: 0.08, blue: 0.06)))
        }

        // Mandíbula inferior
        c.fill(lowerRot, with: .linearGradient(
            Gradient(colors: [Color(red: 0.95, green: 0.48, blue: 0.06), Color(red: 0.82, green: 0.32, blue: 0.0)]),
            startPoint: CGPoint(x: 80, y: 58), endPoint: CGPoint(x: 90, y: 74)))
        c.drawLayer { l in
            l.clip(to: lowerRot)
            var tip = Path()
            tip.move(to: CGPoint(x: 108, y: 50))
            tip.addLine(to: CGPoint(x: 150, y: 50))
            tip.addLine(to: CGPoint(x: 150, y: 90))
            tip.addQuadCurve(to: CGPoint(x: 108, y: 50), control: CGPoint(x: 104, y: 72))
            tip.closeSubpath()
            l.fill(tip.applying(rot), with: .color(TucaPalette.tip))
        }

        // Mandíbula superior com ponta escura e brilho
        c.fill(upper, with: .linearGradient(
            Gradient(stops: [.init(color: TucaPalette.beakLight, location: 0),
                             .init(color: TucaPalette.beak, location: 0.45),
                             .init(color: Color(red: 1, green: 0.37, blue: 0), location: 1)]),
            startPoint: CGPoint(x: 75, y: 20), endPoint: CGPoint(x: 92, y: 62)))
        c.drawLayer { l in
            l.clip(to: upper)
            var tip = Path()
            tip.move(to: CGPoint(x: 100, y: 4))
            tip.addQuadCurve(to: CGPoint(x: 112, y: 76), control: CGPoint(x: 98, y: 44))
            tip.addLine(to: CGPoint(x: 150, y: 74))
            tip.addLine(to: CGPoint(x: 150, y: 8))
            tip.closeSubpath()
            l.fill(tip, with: .linearGradient(
                Gradient(colors: [Color(red: 0.24, green: 0.25, blue: 0.29), TucaPalette.tip]),
                startPoint: CGPoint(x: 104, y: 22), endPoint: CGPoint(x: 134, y: 64)))
        }
        var seam = Path()
        seam.move(to: CGPoint(x: 70, y: 58))
        seam.addQuadCurve(to: CGPoint(x: 136, y: 71), control: CGPoint(x: 112, y: 62))
        c.stroke(seam, with: .color(.black.opacity(0.35)), lineWidth: 1)
        if detailed {
            c.drawLayer { l in
                l.clip(to: upper)
                var gloss = Path()
                gloss.move(to: CGPoint(x: 70, y: 24))
                gloss.addQuadCurve(to: CGPoint(x: 100, y: 15), control: CGPoint(x: 84, y: 14))
                l.stroke(gloss, with: .color(.white.opacity(0.4)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }
        }
    }

    // MARK: Acessórios

    private static func speedLines(_ c: GraphicsContext, t: Double) {
        for (i, y) in [62.0, 74.0, 86.0].enumerated() {
            let k = 0.5 + 0.5 * sin(t * 10 + Double(i) * 1.7)
            var l = Path()
            l.move(to: CGPoint(x: 0, y: y))
            l.addLine(to: CGPoint(x: 10 + 6 * k, y: y))
            c.stroke(l, with: .color(TucaPalette.eyeColor.opacity(0.35 + 0.4 * k)),
                     style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }

    private static func thinkingDots(_ c: GraphicsContext, t: Double, reduce: Bool) {
        for (i, (x, y, r)) in [(84.0, 12.0, 2.0), (92.0, 7.0, 2.6), (101.0, 3.0, 3.2)].enumerated() {
            let a = reduce ? 0.9 : 0.35 + 0.65 * max(0, sin(t * 4 - Double(i) * 0.8))
            c.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)),
                   with: .color(TucaPalette.eyeColor.opacity(a)))
        }
    }

    private static func attentionMarks(_ c: GraphicsContext, t: Double, reduce: Bool) {
        let k = reduce ? 1 : 0.6 + 0.4 * sin(t * 6)
        for (a, b) in [(CGPoint(x: 92, y: 10), CGPoint(x: 95, y: 1)),
                       (CGPoint(x: 100, y: 14), CGPoint(x: 108, y: 7)),
                       (CGPoint(x: 104, y: 22), CGPoint(x: 113, y: 20))] {
            var l = Path()
            l.move(to: a)
            l.addLine(to: b)
            c.stroke(l, with: .color(TucaPalette.accent.opacity(k)), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        }
    }

    private static func sparkles(_ c: GraphicsContext, e: CGFloat) {
        let a = Double(max(0, 1 - e / 2.5))
        for (x, y, r) in [(18.0, 14.0, 4.0), (100.0, 6.0, 3.2), (10.0, 40.0, 2.6)] {
            var star = Path()
            star.move(to: CGPoint(x: x, y: y - r))
            star.addLine(to: CGPoint(x: x + r * 0.3, y: y - r * 0.3))
            star.addLine(to: CGPoint(x: x + r, y: y))
            star.addLine(to: CGPoint(x: x + r * 0.3, y: y + r * 0.3))
            star.addLine(to: CGPoint(x: x, y: y + r))
            star.addLine(to: CGPoint(x: x - r * 0.3, y: y + r * 0.3))
            star.addLine(to: CGPoint(x: x - r, y: y))
            star.addLine(to: CGPoint(x: x - r * 0.3, y: y - r * 0.3))
            star.closeSubpath()
            c.fill(star, with: .color(Color(red: 1, green: 0.78, blue: 0.25).opacity(a)))
        }
    }

    private static func zzz(_ c: GraphicsContext, t: Double, reduce: Bool) {
        for i in 0..<3 {
            let phase = reduce ? 0.5 : (t * 0.5 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
            let x = 96 + Double(i) * 9
            let y = 30 - Double(i) * 9 - phase * 4
            let size = 7 + Double(i) * 2
            c.draw(Text("z").font(.system(size: size, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.55, green: 0.7, blue: 1).opacity(reduce ? 0.8 : 1 - phase * 0.6)),
                   at: CGPoint(x: x, y: y))
        }
    }

    private static func incomingFile(_ c: GraphicsContext, r: CGFloat) {
        let k = r / 0.6
        let x = 124 - 14 * k
        let y = -6 + 62 * k
        let sc = 1 - 0.7 * k
        let w = 14 * sc, h = 18 * sc
        let rect = CGRect(x: x - w / 2, y: y - h / 2, width: w, height: h)
        c.fill(Path(roundedRect: rect, cornerRadius: 2.5 * sc), with: .color(.white))
        c.fill(Path(CGRect(x: rect.minX, y: rect.minY, width: w, height: h * 0.28)), with: .color(TucaPalette.eyeColor))
    }

    // MARK: Utilidades

    static func blinkAmount(_ t: Double) -> CGFloat {
        let period = 4.6
        let n = floor(t / period)
        let local = t - n * period
        let offset = 0.4 + hash(n) * 3.4
        func pulse(_ start: Double) -> CGFloat {
            let d = local - start
            guard d >= 0 && d < 0.16 else { return 0 }
            return CGFloat(sin(.pi * d / 0.16))
        }
        var b = pulse(offset)
        if hash(n + 17) > 0.75 { b = max(b, pulse(offset + 0.28)) }
        return b
    }

    private static func hash(_ n: Double) -> Double {
        let x = sin(n * 12.9898) * 43758.5453
        return x - floor(x)
    }

    private static func rotation(_ a: CGFloat, around p: CGPoint) -> CGAffineTransform {
        CGAffineTransform(translationX: p.x, y: p.y).rotated(by: a).translatedBy(x: -p.x, y: -p.y)
    }
}
