import AppKit
import SwiftUI
import TucaCore

// O Tuca é a arte oficial aprovada (Docs/MascotKit/00_MASTER/TUCA_MASTER_APPROVED.png).
// Este arquivo NÃO desenha o personagem: ele compõe o asset oficial com transformações
// SwiftUI (escala, rotação, deslocamento, opacidade) e overlays de estado.
// Estados sem arte própria reutilizam o mesmo Tuca aprovado, nunca uma variação gerada em código.

// MARK: - Assets oficiais

enum TucaArt {
    /// Tuca do master com fundo transparente (RGB idêntico ao master; ver Resources/TucaMascotAssets).
    static let base = load("tuca_base")
    /// Mesma arte reduzida com Lanczos para o notch (24 a 40 pt).
    static let small = load("tuca_base_small")
    static let attentionBadge = load("attention_badge")
    static let fileBadge = load("file_badge")
    static let sleepZzz = load("sleep_zzz")
    static let successSpark = load("success_spark")

    /// Proporção da arte (largura / altura).
    static var aspect: CGFloat {
        guard let b = base, b.size.height > 0 else { return 1.78 }
        return b.size.width / b.size.height
    }

    private static func load(_ name: String) -> NSImage? {
        // App instalado: Tuca.app/Contents/Resources/TucaMascot
        if let u = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "TucaMascot") {
            return NSImage(contentsOf: u)
        }
        // Desenvolvimento (.build/release/Tuca): procura Resources/TucaMascotAssets subindo pastas.
        var dir = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath().deletingLastPathComponent()
        for _ in 0..<6 {
            let u = dir.appendingPathComponent("Resources/TucaMascotAssets/\(name).png")
            if FileManager.default.fileExists(atPath: u.path) { return NSImage(contentsOf: u) }
            dir = dir.deletingLastPathComponent()
        }
        NSLog("Tuca: asset oficial ausente: \(name).png")
        return nil
    }
}

// MARK: - Entrada compartilhada (estado, cursor, interações)

/// Estado leve lido a cada quadro, sem invalidar o SwiftUI.
final class TucaFX {
    static let shared = TucaFX()

    var mouse: CGPoint = .zero
    var anchor: CGPoint = .zero
    var clickAt: Date = .distantPast
    var receivedAt: Date = .distantPast
    var dragHover = false
    /// Fornecido pelo app: entradas do resolvedor a partir das sessões, do chat e do notch.
    var inputs: ((Date) -> TucaInputs)?

    private var animators: [String: MotionAnimator] = [:]

    func animator(_ slot: String) -> MotionAnimator {
        if let a = animators[slot] { return a }
        let a = MotionAnimator()
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

// MARK: - Postura por estado (só transformações sobre a arte oficial)

struct TucaMotion {
    var scale: CGFloat = 1
    var rotation: CGFloat = 0      // rad; positivo inclina o bico para baixo
    var dx: CGFloat = 0            // fração da largura
    var dy: CGFloat = 0            // fração da altura
    var opacity: CGFloat = 1
    var saturation: CGFloat = 1
    var track: CGFloat = 0.5       // peso do cursor

    static func lerp(_ a: TucaMotion, _ b: TucaMotion, _ t: CGFloat) -> TucaMotion {
        func m(_ x: CGFloat, _ y: CGFloat) -> CGFloat { x + (y - x) * t }
        return TucaMotion(scale: m(a.scale, b.scale), rotation: m(a.rotation, b.rotation), dx: m(a.dx, b.dx),
                          dy: m(a.dy, b.dy), opacity: m(a.opacity, b.opacity),
                          saturation: m(a.saturation, b.saturation), track: m(a.track, b.track))
    }

    static func target(_ s: TucaVisualState, _ i: TucaInteraction) -> TucaMotion {
        var m = TucaMotion()
        switch s {
        case .idle: break
        case .watching: m.scale = 1.02; m.track = 1
        case .thinking: m.rotation = -0.05; m.track = 0.2
        case .working: m.rotation = 0.015; m.track = 0.2
        case .reading: m.rotation = 0.06; m.dy = 0.02; m.track = 0.1
        case .writing: m.rotation = 0.045; m.dy = 0.015; m.track = 0.1
        case .running: m.dx = 0.015; m.track = 0
        case .waiting: m.track = 0.4
        case .needsAttention: m.scale = 1.03; m.track = 0.3
        case .success: m.rotation = -0.04; m.track = 0
        case .error: m.rotation = 0.06; m.dx = -0.03; m.scale = 0.97; m.saturation = 0.8; m.track = 0
        case .sleeping: m.rotation = 0.09; m.dy = 0.05; m.opacity = 0.82; m.saturation = 0.75; m.track = 0
        }
        switch i {
        case .dragHover: m.scale = 1.06; m.track = 1; m.opacity = 1; m.saturation = 1; m.rotation = min(m.rotation, 0)
        case .receivingFile: m.scale = 1.03; m.opacity = 1; m.saturation = 1
        default: break
        }
        return m
    }
}

/// Interpola a postura quando o estado muda (sem cortes secos).
final class MotionAnimator {
    private var from = TucaMotion()
    private var to = TucaMotion()
    private var key = ""
    private(set) var changedAt: Double = 0

    func motion(target: TucaMotion, key: String, t: Double, duration: Double) -> TucaMotion {
        if self.key.isEmpty {
            from = target; to = target; self.key = key; changedAt = t
        } else if key != self.key {
            from = current(t, duration); to = target; self.key = key; changedAt = t
        } else {
            to = target
        }
        return current(t, duration)
    }

    private func current(_ t: Double, _ d: Double) -> TucaMotion {
        let p = d <= 0 ? 1 : min(1, max(0, (t - changedAt) / d))
        return TucaMotion.lerp(from, to, CGFloat(1 - pow(1 - p, 3)))
    }
}

// MARK: - View

/// O Tuca no app: arte oficial + transformações + overlays de estado.
struct TucaMascotView: View {
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
            let base = anim.motion(target: TucaMotion.target(state, inter), key: "\(state)|\(inter)",
                                   t: t, duration: reduce ? 0 : 0.35)
            let since = t - anim.changedAt
            GeometryReader { geo in
                TucaComposition(size: geo.size, state: state, interaction: inter, base: base,
                                t: t, since: since, cursor: Self.cursor(fx), fx: fx, reduce: reduce)
            }
            .accessibilityElement()
            .accessibilityLabel("Tuca, \(state.label)")
        }
    }

    private static func cursor(_ fx: TucaFX) -> CGPoint {
        func clamp(_ v: CGFloat) -> CGFloat { max(-1, min(1, v)) }
        return CGPoint(x: clamp((fx.mouse.x - fx.anchor.x) / 350), y: clamp(-(fx.mouse.y - fx.anchor.y) / 220))
    }
}

private struct TucaComposition: View {
    let size: CGSize
    let state: TucaVisualState
    let interaction: TucaInteraction
    let base: TucaMotion
    let t: Double
    let since: Double
    let cursor: CGPoint
    let fx: TucaFX
    let reduce: Bool

    var body: some View {
        // Área da arte (aspect fit, centralizada).
        let ar = TucaArt.aspect
        let w = min(size.width, size.height * ar)
        let h = w / ar
        let compact = h < 40          // 24 a 40 pt: só a arte, sem overlays
        let art = (compact ? TucaArt.small : nil) ?? TucaArt.base
        let m = motion()

        ZStack {
            if let art {
                if state == .running && !reduce && !compact {
                    // Rastro de movimento controlado.
                    artImage(art)
                        .opacity(0.22)
                        .blur(radius: 1.5)
                        .offset(x: -w * 0.05 + m.dx * w, y: m.dy * h)
                }
                artImage(art)
                    .scaleEffect(x: m.sx, y: m.sy, anchor: .bottom)
                    .rotationEffect(.radians(Double(m.rotation)), anchor: UnitPoint(x: 0.42, y: 0.9))
                    .offset(x: m.dx * w, y: m.dy * h)
                    .opacity(Double(m.opacity))
                    .saturation(Double(m.saturation))
            }
            if !compact {
                overlays(w: w, h: h)
            }
        }
        .frame(width: w, height: h)
        .frame(width: size.width, height: size.height)
    }

    private func artImage(_ img: NSImage) -> some View {
        Image(nsImage: img)
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .aspectRatio(contentMode: .fit)
    }

    // MARK: Movimento

    private struct Resolved {
        var sx: CGFloat, sy: CGFloat, rotation: CGFloat, dx: CGFloat, dy: CGFloat, opacity: CGFloat, saturation: CGFloat
    }

    private func motion() -> Resolved {
        var r = Resolved(sx: base.scale, sy: base.scale, rotation: base.rotation, dx: base.dx, dy: base.dy,
                         opacity: base.opacity, saturation: base.saturation)
        guard !reduce else { return r }
        let e = CGFloat(since)

        // Respiração de 1,5% (idle e todos os estados calmos).
        r.sy *= 1 + 0.015 * CGFloat(sin(t * 2 * .pi * 0.25))

        // Cursor: deslocamento e inclinação sutis, limitados.
        r.dx += cursor.x * 0.015 * base.track
        r.dy += cursor.y * 0.01 * base.track
        r.rotation += cursor.y * 0.03 * base.track

        switch state {
        case .thinking:
            r.dy -= 0.012 * CGFloat(sin(t * 1.6))
            r.rotation += 0.012 * CGFloat(sin(t * 1.1))
        case .working:
            r.dy += 0.006 * CGFloat(sin(t * 5))
        case .writing:
            r.rotation += 0.02 * CGFloat(max(0, sin(t * 6)))
        case .reading:
            r.rotation += 0.008 * CGFloat(sin(t * 0.8))
        case .running:
            r.dx += 0.008 * CGFloat(sin(t * 14))
        case .waiting:
            r.rotation += 0.015 * CGFloat(sin(t * 0.9))
        case .needsAttention:
            // Pulo curto a cada 1,4 s.
            let ph = (t.truncatingRemainder(dividingBy: 1.4)) / 1.4
            if ph < 0.25 { r.dy -= 0.05 * CGFloat(sin(.pi * ph / 0.25)) }
        case .success:
            if e < 0.9 { r.dy -= 0.08 * CGFloat(sin(.pi * Double(e) / 0.9)) }
        case .error:
            r.dx -= 0.04 * CGFloat(exp(-Double(e) * 6))
        default:
            break
        }

        switch interaction {
        case .clickReaction:
            let c = CGFloat(Date().timeIntervalSince(fx.clickAt))
            let k = CGFloat(sin(.pi * Double(min(c, 0.6)) / 0.6))
            r.sy *= 1 - 0.06 * k
            r.sx *= 1 + 0.04 * k
        case .receivingFile:
            let c = Date().timeIntervalSince(fx.receivedAt)
            if c > 0.45 && c < 0.8 {
                let k = CGFloat(sin(.pi * (c - 0.45) / 0.35))
                r.sy *= 1 - 0.05 * k
                r.sx *= 1 + 0.03 * k
            }
        case .dragHover:
            r.dy -= 0.01 * CGFloat(sin(t * 3))
        default:
            break
        }
        return r
    }

    // MARK: Overlays (SVG oficiais rasterizados e marcadores de estado)

    @ViewBuilder
    private func overlays(w: CGFloat, h: CGFloat) -> some View {
        let e = since
        switch state {
        case .needsAttention:
            if let img = TucaArt.attentionBadge {
                let k = reduce ? 1 : 1 + 0.08 * sin(t * 6)
                badge(img, size: h * 0.3 * k, x: 0.6 * w, y: 0.06 * h, w: w, h: h)
            }
        case .success:
            if let img = TucaArt.successSpark {
                let a = reduce ? 1 : max(0, 1 - e / 2.5)
                ZStack {
                    badge(img, size: h * 0.2, x: 0.18 * w, y: 0.08 * h, w: w, h: h)
                    badge(img, size: h * 0.14, x: 0.66 * w, y: 0.02 * h, w: w, h: h)
                    badge(img, size: h * 0.11, x: 0.08 * w, y: 0.36 * h, w: w, h: h)
                }
                .opacity(a)
            }
        case .sleeping:
            if let img = TucaArt.sleepZzz {
                let f = reduce ? 0 : CGFloat(sin(t * 1.2)) * 0.03 * h
                badge(img, size: h * 0.36, x: 0.66 * w, y: 0.04 * h + f, w: w, h: h, aspect: 1.5)
                    .opacity(reduce ? 0.9 : 0.6 + 0.4 * (0.5 + 0.5 * sin(t * 1.2)))
            }
        case .thinking:
            ThinkingDots(t: t, reduce: reduce)
                .frame(width: h * 0.3, height: h * 0.16)
                .position(x: 0.66 * w, y: 0.06 * h)
        case .running:
            if !reduce { SpeedLines(t: t).frame(width: w * 0.12, height: h * 0.36).position(x: 0.05 * w, y: 0.62 * h) }
            chip(state, w: w, h: h)
        case .reading, .writing, .working, .waiting, .error:
            chip(state, w: w, h: h)
        default:
            EmptyView()
        }
        switch interaction {
        case .dragHover:
            if let img = TucaArt.fileBadge {
                let b = reduce ? 0 : CGFloat(sin(t * 4)) * 0.03 * h
                badge(img, size: h * 0.3, x: 0.84 * w, y: 0.1 * h + b, w: w, h: h)
            }
        case .receivingFile:
            if let img = TucaArt.fileBadge {
                let c = CGFloat(Date().timeIntervalSince(fx.receivedAt))
                if c < 0.6 {
                    let k = reduce ? 1 : c / 0.6
                    badge(img, size: h * 0.3 * (1 - 0.7 * k),
                          x: (0.92 - 0.2 * k) * w, y: (-0.02 + 0.5 * k) * h, w: w, h: h)
                        .opacity(Double(1 - 0.6 * k))
                }
            }
        default:
            EmptyView()
        }
    }

    private func badge(_ img: NSImage, size: CGFloat, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat,
                       aspect: CGFloat = 1) -> some View {
        Image(nsImage: img)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: size * aspect, height: size)
            .position(x: x, y: y)
    }

    /// Marcador de estado (símbolo + cor) no canto do bico, para estados sem arte própria.
    private func chip(_ s: TucaVisualState, w: CGFloat, h: CGFloat) -> some View {
        let d = h * 0.26
        return ZStack {
            Circle().fill(Color.black.opacity(0.75))
            Circle().stroke(s.tint.opacity(0.9), lineWidth: max(1, d * 0.06))
            Image(systemName: s.symbol)
                .font(.system(size: d * 0.5, weight: .semibold))
                .foregroundStyle(s.tint)
        }
        .frame(width: d, height: d)
        .position(x: 0.9 * w, y: 0.14 * h)
    }
}

private struct ThinkingDots: View {
    let t: Double
    let reduce: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color(red: 0.082, green: 0.651, blue: 1.0))
                    .frame(width: CGFloat(4 + i * 2), height: CGFloat(4 + i * 2))
                    .opacity(reduce ? 0.9 : 0.35 + 0.65 * max(0, sin(t * 4 - Double(i) * 0.8)))
            }
        }
    }
}

private struct SpeedLines: View {
    let t: Double

    var body: some View {
        GeometryReader { g in
            ForEach(0..<3, id: \.self) { i in
                let k = 0.5 + 0.5 * sin(t * 10 + Double(i) * 1.7)
                Capsule()
                    .fill(Color(red: 0.082, green: 0.651, blue: 1.0).opacity(0.3 + 0.4 * k))
                    .frame(width: g.size.width * (0.6 + 0.4 * k), height: max(1.5, g.size.height * 0.07))
                    .position(x: g.size.width * 0.5, y: g.size.height * (0.2 + 0.3 * Double(i)))
            }
        }
    }
}

// MARK: - Rótulo de estado

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
        case .thinking: Color(red: 0.082, green: 0.651, blue: 1.0)
        default: Color.secondary
        }
    }
}
