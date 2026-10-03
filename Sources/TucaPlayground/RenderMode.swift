import AppKit
import ImageIO
import TucaCharacter
import TucaCore
import UniformTypeIdentifiers

/// `TucaPlayground --render <pasta>` grava sequências quadro a quadro (20 fps) de cada estado e
/// interação, numa tira vertical por sequência, para revisão e geração de GIF.
@MainActor
enum RenderMode {
    static let fps = 20.0
    static let frameSize = CGSize(width: 400, height: 240)

    static func run(dir: String) {
        _ = NSApplication.shared
        let out = URL(fileURLWithPath: dir)
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

        for s in TucaVisualState.allCases {
            sequence("state_\(s.rawValue)", seconds: s == .idle ? 6 : 3.5, out: out) { v, t in
                if t == 0.3 { v.state = s }
            }
        }
        sequence("watch_cursor", seconds: 4, out: out, cursor: { t in CGPoint(x: cos(t * 2.2), y: 0.6 * sin(t * 2.2)) }) { v, t in
            if t == 0.3 { v.state = .watching }
        }
        sequence("idle_cursor_awareness", seconds: 4, out: out, cursor: { t in t < 1.5 ? CGPoint(x: -0.8, y: 0.4) : CGPoint(x: min(1, -0.8 + (t - 1.5) * 1.2), y: 0.4 - (t - 1.5) * 0.5) }) { _, _ in }
        sequence("click_escalation", seconds: 3.5, out: out) { v, t in
            if [0.4, 0.6, 0.8, 1.0].contains(t) { v.click() }
        }
        sequence("drag_receive", seconds: 3, out: out, cursor: { t in CGPoint(x: max(0.2, 1 - t * 0.5), y: -0.4) }) { v, t in
            if t == 0.4 { v.dragHovering = true }
            if t == 1.6 { v.dragHovering = false; v.receiveFile() }
        }
        sequence("sleep_wake", seconds: 4.5, out: out) { v, t in
            if t == 0.1 { v.state = .sleeping }
            if t == 2.5 { v.wakeUp() }
        }
        sequence("tour_thinking_reading_writing_success", seconds: 9, out: out) { v, t in
            if t == 0.3 { v.state = .thinking }
            if t == 2.5 { v.state = .reading }
            if t == 4.7 { v.state = .writing }
            if t == 6.9 { v.state = .success }
        }
        sequence("reduce_motion_attention", seconds: 2, out: out, reduce: true) { v, t in
            if t == 0.3 { v.state = .needsAttention }
        }
        sizes(out: out)
        notchPreview(out: out)
        print("ok")
    }

    static func sequence(_ name: String, seconds: Double, out: URL, reduce: Bool = false,
                         cursor: ((Double) -> CGPoint)? = nil,
                         script: (TucaCharacterView, Double) -> Void) {
        let v = TucaCharacterView(frame: CGRect(origin: .zero, size: frameSize), seed: 7, manualClock: true)
        v.reduceMotionOverride = reduce
        v.onWake = { [weak v] in v?.state = .idle }
        var clock = 0.0
        if let cursor { v.cursorOverride = { cursor(clock) } } else { v.cursorOverride = { nil } }
        let n = Int(seconds * fps)
        let W = Int(frameSize.width), H = Int(frameSize.height)
        guard let ctx = CGContext(data: nil, width: W, height: H * n, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        ctx.setFillColor(CGColor(gray: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: W, height: H * n))
        let base = 1000.0
        for k in 0..<n {
            clock = Double(k) / fps
            let t = (Double(k) / fps * 100).rounded() / 100
            script(v, t)
            v.advance(to: base + Double(k) / fps)
            if let img = v.renderImage() {
                ctx.draw(img, in: CGRect(x: 0, y: H * (n - 1 - k), width: W, height: H))
            }
        }
        save(ctx.makeImage(), out.appendingPathComponent(name + ".png"))
    }

    static func sizes(out: URL) {
        let hs: [CGFloat] = [24, 32, 48, 64, 96, 128, 256]
        let scale: CGFloat = 2
        let totalW = hs.reduce(0) { $0 + $1 * 1.18 * 1.78 + 16 }
        let maxH = 256 * 1.32 + 30
        guard let ctx = CGContext(data: nil, width: Int(totalW * scale), height: Int(maxH * scale), bitsPerComponent: 8,
                                  bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        ctx.setFillColor(CGColor(gray: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: totalW * scale, height: maxH * scale))
        var x: CGFloat = 0
        for h in hs {
            let size = CGSize(width: h * 1.18 * 1.78, height: h * 1.32)
            let v = TucaCharacterView(frame: CGRect(origin: .zero, size: size), seed: 3, manualClock: true)
            v.cursorOverride = { nil }
            v.state = .idle
            v.advance(to: 500)
            v.advance(to: 500.5)
            if let img = v.renderImage(scale: scale) {
                ctx.draw(img, in: CGRect(x: x * scale, y: 0, width: size.width * scale, height: size.height * scale))
            }
            x += size.width + 16
        }
        save(ctx.makeImage(), out.appendingPathComponent("sizes_24_to_256.png"))
    }

    /// O personagem nas medidas reais do notch: recolhido, cabeçalho e área de soltar.
    static func notchPreview(out: URL) {
        let slots: [(CGSize, CGSize, TucaVisualState)] = [
            (CGSize(width: 33 * 1.78 * 1.04 / 1.06, height: 33), CGSize(width: 1.04, height: 1.06), .running),
            (CGSize(width: 70, height: 42), CGSize(width: 1.08, height: 1.14), .needsAttention),
            (CGSize(width: 190, height: 104), CGSize(width: 1.18, height: 1.32), .idle),
        ]
        let scale: CGFloat = 3
        let W = slots.reduce(0) { $0 + $1.0.width + 20 }, H: CGFloat = 110
        guard let ctx = CGContext(data: nil, width: Int(W * scale), height: Int(H * scale), bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        ctx.setFillColor(CGColor(gray: 0, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: W * scale, height: H * scale))
        var x: CGFloat = 0
        for (size, margins, st) in slots {
            let v = TucaCharacterView(frame: CGRect(origin: .zero, size: size), seed: 5, manualClock: true)
            v.fitMargins = margins
            v.cursorOverride = { nil }
            v.advance(to: 300)
            v.state = st
            v.advance(to: 301.2)
            if let img = v.renderImage(scale: scale) {
                ctx.setStrokeColor(CGColor(gray: 0.35, alpha: 1)); ctx.setLineWidth(1)
                ctx.stroke(CGRect(x: x * scale, y: (H - size.height) * scale, width: size.width * scale, height: size.height * scale))
                ctx.draw(img, in: CGRect(x: x * scale, y: (H - size.height) * scale, width: size.width * scale, height: size.height * scale))
            }
            x += size.width + 20
        }
        save(ctx.makeImage(), out.appendingPathComponent("notch_slots.png"))
    }

    static func save(_ img: CGImage?, _ url: URL) {
        guard let img, let d = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(d, img, nil)
        CGImageDestinationFinalize(d)
    }
}
