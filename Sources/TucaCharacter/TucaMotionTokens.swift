import CoreGraphics
import Foundation

/// Parâmetros de uma mola física (rigidez e amortecimento relativo; 1 = crítico).
public struct SpringSpec: Sendable {
    public let stiffness: Double
    public let damping: Double
}

/// Tokens de movimento do Tuca. Todo timing, amplitude e mola do personagem vem daqui;
/// nenhum valor solto de animação fica espalhado pelo código.
public enum TucaMotionTokens {
    // Molas por canal
    public static let look = SpringSpec(stiffness: 420, damping: 0.82)      // olhar (sacadas rápidas)
    public static let eye = SpringSpec(stiffness: 900, damping: 0.72)       // abertura do olho
    public static let head = SpringSpec(stiffness: 140, damping: 0.55)      // inclinação
    public static let body = SpringSpec(stiffness: 170, damping: 0.5)       // deslocamento
    public static let squash = SpringSpec(stiffness: 320, damping: 0.42)    // squash and stretch
    public static let overlay = SpringSpec(stiffness: 220, damping: 0.62)   // entrada de overlays

    // Olhos
    public static let blinkSeconds = 0.12
    public static let blinkInterval: ClosedRange<Double> = 2.2...6.0
    public static let doubleBlinkChance = 0.2
    /// Deslocamento máximo da íris, em pixels da arte (cerca de 10% do olho).
    public static let maxEyeTravel = CGVector(dx: 5.5, dy: 4.0)
    /// Distância (pt) do cursor em que o olhar chega ao máximo.
    public static let cursorFalloff: Double = 220
    public static let cursorAwareSeconds = 1.6
    public static let glanceInterval: ClosedRange<Double> = 2.5...6.0

    // Cabeça e corpo
    public static let maxHeadTilt = 6.0 * Double.pi / 180
    public static let postureInterval: ClosedRange<Double> = 5.0...10.0
    public static let idleBreathScale = 0.018
    public static let idleBreathPeriod = 3.6
    public static let sleepBreathScale = 0.03
    public static let sleepBreathPeriod = 5.6

    // Estados e interações
    public static let successSeconds = 1.2
    public static let errorShakeSeconds = 0.6
    public static let attentionHopPeriod = 1.6
    public static let multiClickWindow = 1.2
    public static let irritatedClicks = 3
    public static let irritatedSeconds = 1.6
    public static let receiveFlightSeconds = 0.5
    public static let wakeSeconds = 0.9

    /// Abaixo desta altura (pt) os overlays somem: no notch só a silhueta, o olho e o bico.
    public static let overlayMinHeight: Double = 48
}

/// Mola amortecida integrada em subpassos fixos (estável em qualquer taxa de quadros).
struct Spring {
    var value: Double
    var velocity: Double = 0
    var target: Double
    let spec: SpringSpec

    init(_ v: Double, _ spec: SpringSpec) {
        value = v
        target = v
        self.spec = spec
    }

    mutating func step(_ dt: Double) {
        let k = spec.stiffness
        let c = 2 * k.squareRoot() * spec.damping
        var remaining = dt
        while remaining > 1e-6 {
            let h = min(remaining, 1.0 / 240)
            velocity += (-k * (value - target) - c * velocity) * h
            value += velocity * h
            remaining -= h
        }
    }

    mutating func snap() {
        value = target
        velocity = 0
    }
}

/// Gerador determinístico (usado na renderização de verificação).
struct SeededRNG: RandomNumberGenerator {
    private var s: UInt64
    init(_ seed: UInt64) { s = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }
    mutating func next() -> UInt64 {
        s ^= s << 13
        s ^= s >> 7
        s ^= s << 17
        return s
    }
}
