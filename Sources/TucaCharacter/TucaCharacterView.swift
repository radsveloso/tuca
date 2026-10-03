import AppKit
import QuartzCore
import TucaCore

/// O Tuca vivo: rig em Core Animation montado com camadas derivadas do master aprovado.
/// O estado vem de fora (TucaCore); a vida (respiração, olhar, piscar, reações) vem deste motor.
@MainActor
public final class TucaCharacterView: NSView {

    // MARK: API pública

    public var state: TucaVisualState = .idle {
        didSet { if state != oldValue { enterState(from: oldValue) } }
    }
    /// Cursor sobre o personagem.
    public var hovering = false {
        didSet { if hovering && !oldValue { activity() } }
    }
    /// Arquivo sendo arrastado sobre o personagem.
    public var dragHovering = false {
        didSet { if dragHovering && !oldValue { dragEnter() } }
    }
    public var followsCursor = true
    /// nil = segue a preferência do sistema (Reduzir movimento).
    public var reduceMotionOverride: Bool?
    /// Chamado quando uma atividade acorda o Tuca dormindo.
    public var onWake: (() -> Void)?
    /// Chamado quando um arquivo é solto no personagem.
    public var onDropFiles: (([URL]) -> Void)?
    /// false quando quem recebe o arraste é a interface em volta (o notch).
    public var acceptsFileDrops = true {
        didSet { if acceptsFileDrops { registerForDraggedTypes([.fileURL]) } else { unregisterDraggedTypes() } }
    }
    /// Substitui o cursor real (modo de renderização de verificação). Vetor de olhar -1...1.
    public var cursorOverride: (() -> CGPoint?)?
    /// Texto de diagnóstico (montado só quando pedido).
    public var diagnostics: String {
        String(format: "estado: %@ · olho %.2f · olhar (%.2f, %.2f) · inclinação %.1f°%@",
               state.label, eye.value, lookX.value, lookY.value, tilt.value * 180 / .pi,
               reduce ? " · movimento reduzido" : "")
    }
    /// Chamado no início de cada quadro: o app usa para alimentar estado e interações.
    public var onTick: ((TucaCharacterView) -> Void)?
    /// Folga em volta do personagem (largura, altura) para pulos e overlays. No notch, menor.
    public var fitMargins = CGSize(width: 1.18, height: 1.32) { didSet { fit() } }

    public func blink() { startBlink(double: false) }

    public func click() {
        if state == .sleeping { wakeUp(); return }
        clickTimes = clickTimes.filter { now - $0 < T.multiClickWindow } + [now]
        let n = clickTimes.count
        guard !reduce else { startBlink(double: false); return }
        y.velocity -= min(210 + 90 * Double(n - 1), 460)
        sy.velocity -= 3.4
        startBlink(double: false)
        if n >= T.irritatedClicks { irritatedUntil = now + T.irritatedSeconds }
    }

    public func receiveFile() {
        if state == .sleeping { wakeUp() }
        receiveStart = now
    }

    public func wakeUp() {
        wakeStart = now
        if !reduce {
            eye.velocity += 14
            y.velocity -= 170
        }
        onWake?()
    }

    // MARK: Init

    private typealias T = TucaMotionTokens
    private let art: TucaCharacterArt?
    private var rng: RandomNumberGenerator
    private var link: CADisplayLink?
    private let manualClock: Bool

    public init(frame: NSRect, seed: UInt64? = nil, manualClock: Bool = false) {
        art = TucaCharacterArt.shared
        if let seed { rng = SeededRNG(seed) } else { rng = SystemRandomNumberGenerator() }
        self.manualClock = manualClock
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = false
        buildLayers()
        registerForDraggedTypes([.fileURL])
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel("Tuca, \(state.label)")
        scheduleNextBlink()
        nextGlance = 1.5
        nextPosture = 3
    }

    required init?(coder: NSCoder) { fatalError() }

    public override var isFlipped: Bool { false }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard !manualClock else { return }
        link?.invalidate()
        link = nil
        if window != nil {
            let l = displayLink(target: self, selector: #selector(tick(_:)))
            // 60 fps bastam para o personagem e economizam CPU em telas de 120 Hz.
            l.add(to: .main, forMode: .common)
            link = l
            fit()
        }
        updateTrackingAreas()
    }

    @objc private func tick(_ l: CADisplayLink) {
        // Sem trabalho quando ninguém vê o personagem (0% de CPU com o notch escondido).
        guard let w = window, w.isVisible, !isHiddenOrHasHiddenAncestor, !visibleRect.isEmpty,
              bounds.width > 1, bounds.height > 1 else { return }
        advance(to: l.targetTimestamp)
    }

    /// Avança o motor até o instante `t` (segundos). Usado pelo display link e pela renderização offline.
    public func advance(to t: Double) {
        if now == 0 { now = t - 1.0 / 60; stateStart = now }
        let dt = max(0, min(t - now, 1.0 / 15))
        now = t
        onTick?(self)
        update(dt)
        apply()
    }

    // MARK: Camadas

    private let rig = CALayer()
    private let character = CALayer()
    private let bodyLayer = CALayer()
    private let eyeGroup = CALayer()
    private let socketLayer = CALayer()
    private let irisLayer = CALayer()
    private let rimLayer = CALayer()
    private let ghosts = [CALayer(), CALayer()]
    private let overlays = CALayer()
    private let attentionLayer = CALayer()
    private let sparkLayers = [CALayer(), CALayer(), CALayer()]
    private let zzzLayer = CALayer()
    private let docLayer = CALayer()
    private let fileLayer = CALayer()
    private let dotLayers = [CAShapeLayer(), CAShapeLayer(), CAShapeLayer()]
    private let speedLayers = [CAShapeLayer(), CAShapeLayer(), CAShapeLayer()]
    private var irisRestPosition = CGPoint.zero

    private var artSize: CGSize { art?.size ?? CGSize(width: 432, height: 243) }

    /// Retângulo em coordenadas da imagem (origem no topo) para a camada (origem embaixo).
    private func imgRect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> CGRect {
        CGRect(x: x, y: artSize.height - y - h, width: w, height: h)
    }

    private func imgPoint(_ x: Double, _ y: Double) -> CGPoint {
        CGPoint(x: x, y: artSize.height - y)
    }

    private func imageLayer(_ l: CALayer, _ img: CGImage?) {
        l.contents = img
        l.contentsGravity = .resize
        l.minificationFilter = .trilinear
        l.magnificationFilter = .linear
    }

    private func buildLayers() {
        guard let layer, let art else { return }
        let W = art.size.width, H = art.size.height
        rig.bounds = CGRect(x: 0, y: 0, width: W, height: H)
        layer.addSublayer(rig)

        for g in ghosts {
            imageLayer(g, art.full)
            g.bounds = rig.bounds
            g.anchorPoint = CGPoint(x: 0.45, y: 0.04)
            g.position = CGPoint(x: 0.45 * W, y: 0.04 * H)
            g.opacity = 0
            rig.addSublayer(g)
        }

        character.bounds = rig.bounds
        character.anchorPoint = CGPoint(x: 0.45, y: 0.04)   // apoio nos pés
        character.position = CGPoint(x: 0.45 * W, y: 0.04 * H)
        rig.addSublayer(character)

        imageLayer(bodyLayer, art.body)
        bodyLayer.frame = rig.bounds
        character.addSublayer(bodyLayer)

        let eb = art.eyeBox
        let pivotFromBottom = (eb.maxY - art.blinkPivotY) / eb.height
        eyeGroup.anchorPoint = CGPoint(x: 0.5, y: pivotFromBottom)
        eyeGroup.frame = imgRect(eb.minX, eb.minY, eb.width, eb.height)
        character.addSublayer(eyeGroup)
        for (l, img) in [(socketLayer, art.socket), (irisLayer, art.iris), (rimLayer, art.rim)] {
            imageLayer(l, img)
            l.frame = eyeGroup.bounds
            eyeGroup.addSublayer(l)
        }
        irisRestPosition = irisLayer.position

        overlays.frame = rig.bounds
        rig.addSublayer(overlays)
        imageLayer(attentionLayer, art.attention)
        attentionLayer.bounds = CGRect(x: 0, y: 0, width: 66, height: 66)
        imageLayer(zzzLayer, art.zzz)
        zzzLayer.bounds = CGRect(x: 0, y: 0, width: 96, height: 64)
        imageLayer(docLayer, art.file)
        docLayer.bounds = CGRect(x: 0, y: 0, width: 62, height: 62)
        imageLayer(fileLayer, art.file)
        fileLayer.bounds = CGRect(x: 0, y: 0, width: 62, height: 62)
        for s in sparkLayers {
            imageLayer(s, art.spark)
            s.bounds = CGRect(x: 0, y: 0, width: 44, height: 44)
        }
        let blue = CGColor(red: 0.082, green: 0.651, blue: 1.0, alpha: 1)
        for (i, d) in dotLayers.enumerated() {
            let r = 6.0 + 3.5 * Double(i)
            d.path = CGPath(ellipseIn: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r), transform: nil)
            d.fillColor = blue
        }
        for s in speedLayers {
            s.path = CGPath(roundedRect: CGRect(x: -22, y: -2.5, width: 44, height: 5), cornerWidth: 2.5, cornerHeight: 2.5, transform: nil)
            s.fillColor = blue
        }
        for l in [docLayer, attentionLayer, zzzLayer, fileLayer] + sparkLayers + dotLayers + speedLayers {
            l.opacity = 0
            overlays.addSublayer(l)
        }
    }

    public override func layout() {
        super.layout()
        fit()
    }

    private var fitScale: CGFloat = 1

    private func fit() {
        let W = artSize.width, H = artSize.height
        let s = min(bounds.width / (W * fitMargins.width), bounds.height / (H * fitMargins.height))
        fitScale = max(s, 0.01)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        rig.position = CGPoint(x: bounds.midX, y: bounds.midY - H * fitScale * 0.06)
        rig.setAffineTransform(CGAffineTransform(scaleX: fitScale, y: fitScale))
        CATransaction.commit()
        let compact = Double(H * fitScale) < T.overlayMinHeight
        link?.preferredFrameRateRange = compact
            ? CAFrameRateRange(minimum: 24, maximum: 30, preferred: 30)
            : CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
    }

    // MARK: Estado do motor

    private var now: Double = 0
    private var stateStart: Double = 0
    private var lookX = Spring(0.3, T.look), lookY = Spring(0, T.look)
    private var eye = Spring(1, T.eye)
    private var tilt = Spring(0, T.head)
    private var x = Spring(0, T.body), y = Spring(0, T.body)
    private var sx = Spring(1, T.squash), sy = Spring(1, T.squash)
    private var attentionScale = Spring(0.2, T.overlay)

    private var nextBlink: Double = 0
    private var blinkStart: Double = -10
    private var secondBlinkAt: Double?
    private var glance = CGPoint(x: 0.3, y: 0)
    private var nextGlance: Double = 0
    private var posture: Double = 0
    private var nextPosture: Double = 0
    private var lastCursor: CGPoint?
    private var cursorMovedAt: Double = -10
    private var clickTimes: [Double] = []
    private var irritatedUntil: Double = -10
    private var receiveStart: Double = -10
    private var wakeStart: Double = -10
    private var dragEnterAt: Double = -10
    private var lastHopCycle = -1
    private var pending: [(Double, () -> Void)] = []
    private var history: [CATransform3D] = []

    private var reduce: Bool { reduceMotionOverride ?? NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    private func rand(_ r: ClosedRange<Double>) -> Double { Double.random(in: r, using: &rng) }

    private func scheduleNextBlink() { nextBlink = now + rand(T.blinkInterval) }

    private func startBlink(double: Bool) {
        blinkStart = now
        secondBlinkAt = double ? now + 0.24 : nil
    }

    private func blinkAmount() -> Double {
        var b = 0.0
        for start in [blinkStart, secondBlinkAt.map { $0 } ?? -10] {
            let d = now - start
            if d >= 0 && d < T.blinkSeconds { b = max(b, sin(.pi * d / T.blinkSeconds)) }
        }
        return b
    }

    private func enterState(from old: TucaVisualState) {
        stateStart = now
        setAccessibilityLabel("Tuca, \(state.label)")
        lastHopCycle = -1
        if old == .sleeping && now - wakeStart > 0.25 { wakeUp() }
        guard !reduce else { return }
        switch state {
        case .needsAttention:
            y.value = 60; y.velocity = 0          // emerge de baixo
            sx.value = 0.92; sy.value = 0.92
            attentionScale.value = 0.2
        case .success:
            sy.velocity -= 2.4                    // antecipação
            pending.append((now + 0.12, { [weak self] in
                guard let self else { return }
                self.y.velocity -= 400
                self.sy.velocity += 4
            }))
        case .error:
            x.velocity -= 230                     // recuo
            tilt.velocity -= 3.2
        default:
            break
        }
    }

    private func activity() {
        if state == .sleeping { wakeUp() }
    }

    private func dragEnter() {
        dragEnterAt = now
        if state == .sleeping { wakeUp() }
        guard !reduce else { return }
        sy.velocity -= 2
        y.velocity -= 110
    }

    // MARK: Cursor

    private func cursorLook() -> CGPoint? {
        if let o = cursorOverride { return o() }
        guard followsCursor, let window, let art else { return nil }
        let winPt = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        let p = convert(winPt, from: nil)
        let eyeImg = imgPoint(art.eyeBox.midX, art.eyeBox.midY)
        let e = rig.convert(eyeImg, to: layer)
        func clamp(_ v: Double) -> Double { max(-1, min(1, v)) }
        return CGPoint(x: clamp(Double(p.x - e.x) / T.cursorFalloff), y: clamp(-Double(p.y - e.y) / T.cursorFalloff))
    }

    // MARK: Atualização

    private func update(_ dt: Double) {
        let m = reduce ? 0.0 : 1.0
        let tS = now - stateStart

        // Eventos agendados
        let due = pending.filter { $0.0 <= now }
        pending.removeAll { $0.0 <= now }
        due.forEach { $0.1() }

        // Cursor e consciência do olhar
        let c = cursorLook()
        if let c {
            if let l = lastCursor, hypot(c.x - l.x, c.y - l.y) > 0.01 { cursorMovedAt = now }
            lastCursor = c
        }
        let aware = c != nil && now - cursorMovedAt < T.cursorAwareSeconds

        // Vida no idle: olhadelas e pequenas mudanças de postura
        if now >= nextGlance {
            glance = CGPoint(x: rand(-0.6...0.7), y: rand(-0.45...0.35))
            nextGlance = now + rand(T.glanceInterval)
        }
        if now >= nextPosture {
            posture = rand(-0.03...0.03)
            nextPosture = now + rand(T.postureInterval)
        }
        if state != .sleeping && now >= nextBlink {
            startBlink(double: rand(0...1) < T.doubleBlinkChance)
            scheduleNextBlink()
        }

        // Postura alvo do estado
        var lx = Double(glance.x), ly = Double(glance.y)
        var eyeT = 1.0, tiltT = posture * m, xT = 0.0, yT = 0.0, sxT = 1.0, syT = 1.0
        func osc(_ f: Double) -> Double { sin(now * f) * m }

        switch state {
        case .idle:
            if let c, aware { lx = Double(c.x) * 0.75; ly = Double(c.y) * 0.75; tiltT += Double(c.y) * 0.02 }
        case .watching:
            if let c { lx = Double(c.x); ly = Double(c.y); tiltT = Double(c.y) * 0.05; xT = Double(c.x) * 4 }
            else { lx = 0.7 * osc(0.7); ly = 0 }
            eyeT = 1.04
        case .thinking:
            lx = -0.45 + 0.25 * osc(0.6); ly = -1
            tiltT = -0.11 + 0.025 * osc(0.9); yT = -2 + 2 * osc(1.3); eyeT = 0.92
        case .working:
            let phase = Int(now / 2.2) % 2
            (lx, ly) = phase == 0 ? (0.6, 0.5) : (0.15, 0.25)
            tiltT = 0.03; yT = 1.2 * osc(5); eyeT = 0.88
        case .reading:
            let cyc = 2.0
            let ph = tS.truncatingRemainder(dividingBy: cyc) / cyc
            let line = Int(tS / cyc) % 3
            lx = ph < 0.85 ? -0.7 + 1.4 * (ph / 0.85) : -0.7
            ly = 0.45 + 0.15 * Double(line)
            tiltT = 0.07; yT = 2; eyeT = 0.9
        case .writing:
            let ph = tS.truncatingRemainder(dividingBy: 1.8)
            if ph < 1.2 { lx = 0.55; ly = 0.75; yT = 1.6 * abs(osc(14)) } else { lx = 0; ly = -0.1 }
            tiltT = 0.05
        case .running:
            lx = 0.9; ly = 0.05; tiltT = 0.06
            xT = 3 * osc(12); yT = -4 * abs(osc(6))
            let land = (1 - abs(sin(now * 6))) * m
            syT = 1 - 0.04 * land; sxT = 1 + 0.03 * land
        case .waiting:
            let aside = tS.truncatingRemainder(dividingBy: 3.0) > 2.4
            lx = aside ? 0.75 : 0; ly = aside ? 0 : -0.05
            let b = tS.truncatingRemainder(dividingBy: 2.0)
            if m > 0 && (b < 0.12 || (b > 0.25 && b < 0.37)) { yT = -1.8 }
            tiltT = -0.02; eyeT = 1.02
        case .needsAttention:
            lx = 0; ly = -0.15; sxT = 1.04; syT = 1.04; eyeT = 1.06
            let cycle = Int(tS / T.attentionHopPeriod)
            let ph = tS.truncatingRemainder(dividingBy: T.attentionHopPeriod)
            if cycle != lastHopCycle && m > 0 && tS > 0.5 { lastHopCycle = cycle; y.velocity -= 130 }
            if ph < 0.6 { tiltT = 0.035 * sin(now * 9) * (1 - ph / 0.6) * m }
        case .success:
            if tS < T.successSeconds {
                tiltT = -0.07
                eyeT = 1.08
                lx = 0.1; ly = -0.4
            } else if let c, aware { lx = Double(c.x) * 0.6; ly = Double(c.y) * 0.6 }
        case .error:
            eyeT = 0.62; lx = 0.1; ly = 0.6; tiltT = 0.045; yT = 2
            if tS < T.errorShakeSeconds { tiltT += 0.05 * sin(tS * 30) * (1 - tS / T.errorShakeSeconds) * m }
            let s = tS.truncatingRemainder(dividingBy: 4.0)
            if s > 3.0 { yT += 1.5 * sin(.pi * (s - 3.0)) * m }
        case .sleeping:
            eyeT = 0.04; lx = 0; ly = 0.3; tiltT = 0.09; yT = 5
        }

        // Interações
        if hovering && state != .sleeping, let c {
            lx = Double(c.x); ly = Double(c.y); xT += Double(c.x) * 3; sxT *= 1.02; syT *= 1.02
        }
        if dragHovering {
            let c2 = c ?? CGPoint(x: 0.8, y: -0.3)
            lx = Double(c2.x); ly = Double(c2.y); xT += Double(c2.x) * 5
            eyeT = max(eyeT, 1.08); yT -= 1.5 * abs(osc(8))
        }
        if now < irritatedUntil {
            eyeT = 0.58; lx = 0.7; ly = 0.25
            let left = (irritatedUntil - now) / T.irritatedSeconds
            tiltT += 0.06 * sin(now * 22) * left * m
        }
        let wt = now - wakeStart
        if wt < T.wakeSeconds {
            eyeT = max(eyeT, 1.12)
            lx = wt < 0.3 ? -0.7 : (wt < 0.6 ? 0.7 : 0); ly = -0.1
        }
        let rt = now - receiveStart
        if rt < 1.0 {
            lx = rt < T.receiveFlightSeconds ? 0.9 - 0.6 * rt : 0.3
            ly = rt < T.receiveFlightSeconds ? -0.5 + 1.2 * rt : 0.2
            if rt > 0.5 && rt < 0.75 { let k = sin(.pi * (rt - 0.5) / 0.25) * m; syT *= 1 - 0.06 * k; sxT *= 1 + 0.04 * k }
            if rt > 0.5 && rt < 0.52 && blinkStart < receiveStart { startBlink(double: false) }
        }

        lookX.target = max(-1, min(1, lx)); lookY.target = max(-1, min(1, ly))
        eye.target = eyeT
        tilt.target = max(-T.maxHeadTilt * 1.6, min(T.maxHeadTilt * 1.6, tiltT))
        x.target = xT; y.target = yT; sx.target = sxT; sy.target = syT
        attentionScale.target = state == .needsAttention ? 1 : 0.2

        if reduce {
            lookX.snap(); lookY.snap(); eye.snap(); tilt.snap(); x.snap(); y.snap(); sx.snap(); sy.snap(); attentionScale.snap()
        } else {
            lookX.step(dt); lookY.step(dt); eye.step(dt); tilt.step(dt)
            x.step(dt); y.step(dt); sx.step(dt); sy.step(dt); attentionScale.step(dt)
        }

    }

    // MARK: Aplicação nas camadas

    private func apply() {
        guard art != nil else { return }
        let m = reduce ? 0.0 : 1.0
        let tS = now - stateStart
        let breathAmp = state == .sleeping ? T.sleepBreathScale : T.idleBreathScale
        let breathPeriod = state == .sleeping ? T.sleepBreathPeriod : T.idleBreathPeriod
        let breath = breathAmp * sin(2 * .pi * now / breathPeriod) * m

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        var t = CATransform3DMakeTranslation(x.value, -y.value, 0)
        t = CATransform3DRotate(t, -tilt.value, 0, 0, 1)
        t = CATransform3DScale(t, sx.value * (1 - breath * 0.3), sy.value * (1 + breath), 1)
        character.transform = t

        // Rastro de movimento (executando)
        history.append(t)
        if history.count > 8 { history.removeFirst(history.count - 8) }
        let trail = state == .running && m > 0
        for (i, g) in ghosts.enumerated() where trail || g.opacity != 0 {
            let idx = max(0, history.count - 1 - (i + 1) * 3)
            var gt = history[idx]
            gt = CATransform3DTranslate(gt, -8 * Double(i + 1), 0, 0)
            g.transform = gt
            g.opacity = trail ? (i == 0 ? 0.22 : 0.11) : 0
        }

        // Olho: abertura (piscar/dormir/semicerrar) e íris seguindo o olhar
        let open = max(0.035, min(1.15, eye.value * (1 - blinkAmount())))
        eyeGroup.transform = CATransform3DMakeScale(1, open, 1)
        irisLayer.position = CGPoint(x: irisRestPosition.x + lookX.value * T.maxEyeTravel.dx,
                                     y: irisRestPosition.y - lookY.value * T.maxEyeTravel.dy)

        // Overlays (somem em tamanhos de notch)
        let showOverlays = Double(artSize.height * fitScale) >= T.overlayMinHeight
        overlays.opacity = showOverlays ? 1 : 0
        guard showOverlays else {
            CATransaction.commit()
            return
        }
        overlays.transform = CATransform3DMakeTranslation(x.value * 0.6, -y.value * 0.6, 0)

        let attOn = state == .needsAttention
        attentionLayer.position = imgPoint(326, 14)
        attentionLayer.transform = CATransform3DMakeScale(attentionScale.value * (1 + 0.06 * sin(now * 6) * m),
                                                          attentionScale.value * (1 + 0.06 * sin(now * 6) * m), 1)
        attentionLayer.opacity = attOn ? 1 : 0

        let sparkOn = state == .success && tS < 1.8
        let origin = (250.0, 46.0)
        let ends = [(178.0, -6.0), (318.0, -14.0), (372.0, 34.0)]
        for (i, s) in sparkLayers.enumerated() {
            let k = m > 0 ? min(1, max(0, (tS - 0.1) / 0.7)) : 1
            let e = 1 - pow(1 - k, 3)
            s.position = imgPoint(origin.0 + (ends[i].0 - origin.0) * e, origin.1 + (ends[i].1 - origin.1) * e)
            s.transform = CATransform3DRotate(CATransform3DMakeScale(0.5 + 0.7 * e, 0.5 + 0.7 * e, 1), tS * 3 * m, 0, 0, 1)
            s.opacity = sparkOn ? Float(m > 0 ? max(0, 1 - max(0, tS - 0.9) / 0.9) : 1) : 0
        }

        zzzLayer.position = imgPoint(318, 6 - 10 * (m > 0 ? (now.truncatingRemainder(dividingBy: 2.4) / 2.4) : 0.5))
        zzzLayer.opacity = state == .sleeping ? Float(m > 0 ? 0.55 + 0.45 * sin(now * 1.3) : 0.9) : 0

        let docOn = state == .reading || state == .writing
        docLayer.position = imgPoint(368, 206 + 2 * sin(now * (state == .writing ? 10 : 1.5)) * m)
        docLayer.transform = CATransform3DMakeRotation(-0.12 + 0.04 * sin(now * 1.2) * m, 0, 0, 1)
        docLayer.opacity = docOn ? 1 : 0

        let rt = now - receiveStart
        if rt < T.receiveFlightSeconds {
            let k = m > 0 ? rt / T.receiveFlightSeconds : 1
            let e = k * k
            fileLayer.position = imgPoint(452 - 110 * e, -24 + 136 * e)
            fileLayer.transform = CATransform3DMakeScale(1 - 0.65 * e, 1 - 0.65 * e, 1)
            fileLayer.opacity = Float(1 - 0.3 * e)
        } else {
            fileLayer.opacity = 0
        }

        let thinkOn = state == .thinking
        let dotPos = [(292.0, 30.0), (318.0, 12.0), (350.0, -4.0)]
        for (i, d) in dotLayers.enumerated() {
            d.position = imgPoint(dotPos[i].0, dotPos[i].1)
            let a = m > 0 ? 0.45 + 0.55 * max(0, sin(now * 3.5 - Double(i) * 0.8)) : 0.95
            d.opacity = thinkOn ? Float(a) : 0
        }

        let runOn = state == .running && m > 0
        for (i, s) in speedLayers.enumerated() {
            let k = 0.5 + 0.5 * sin(now * 11 + Double(i) * 1.9)
            s.position = imgPoint(4 - 8 * k, 118 + 30 * Double(i))
            s.transform = CATransform3DMakeScale(0.7 + 0.5 * k, 1, 1)
            s.opacity = runOn ? Float(0.25 + 0.5 * k) : 0
        }

        CATransaction.commit()
    }

    // MARK: Mouse e arraste

    private var trackingArea: NSTrackingArea?

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let a = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(a)
        trackingArea = a
    }

    public override func mouseEntered(with event: NSEvent) { hovering = true }
    public override func mouseExited(with event: NSEvent) { hovering = false }
    public override func mouseDown(with event: NSEvent) { click() }

    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        dragHovering = true
        return .copy
    }

    public override func draggingExited(_ sender: NSDraggingInfo?) { dragHovering = false }

    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        dragHovering = false
        let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] ?? []
        receiveFile()
        onDropFiles?(urls)
        return true
    }

    // MARK: Renderização offline (verificação)

    /// Renderiza o quadro atual numa imagem (para gerar sequências de verificação).
    public func renderImage(scale: CGFloat = 1) -> CGImage? {
        guard let layer else { return nil }
        layoutSubtreeIfNeeded()
        fit()
        let w = Int(bounds.width * scale), h = Int(bounds.height * scale)
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.scaleBy(x: scale, y: scale)
        layer.render(in: ctx)
        return ctx.makeImage()
    }
}
