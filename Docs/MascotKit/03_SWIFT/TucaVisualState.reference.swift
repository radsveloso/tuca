import Foundation

public enum TucaVisualState: String, CaseIterable, Codable {
    case idle, watching, thinking, working, reading, writing, running, waiting
    case needsAttention, success, error, sleeping
}

public enum TucaInteraction: Equatable {
    case none, blink, cursorLook, clickReaction, dragHover, receivingFile
}

public enum TucaStatePriority {
    public static let ordered: [TucaVisualState] = [
        .needsAttention, .error, .running, .writing, .reading, .thinking,
        .working, .success, .watching, .idle, .sleeping
    ]
}
