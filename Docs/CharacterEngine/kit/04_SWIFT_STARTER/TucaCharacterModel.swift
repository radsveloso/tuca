import Foundation

enum TucaVisualState: String, CaseIterable {
    case idle, watching, thinking, working, reading, writing, running, waiting
    case needsAttention, success, error, sleeping
}
enum TucaInteraction {
    case none, blink, cursorLook, hover, click, multiClick, dragHover, receivingFile, wakeUp
}
struct TucaMotionTokens {
    static let blinkSeconds = 0.12
    static let successSeconds = 1.2
    static let maxEyeTravel: Double = 0.10
    static let maxHeadTiltDegrees: Double = 6
    static let idleBreathScale: Double = 0.018
}
