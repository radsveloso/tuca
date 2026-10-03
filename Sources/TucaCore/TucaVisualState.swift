import Foundation

/// Estados visuais do Tuca (Tuca Mascot 2.0).
public enum TucaVisualState: String, CaseIterable, Sendable {
    case idle, watching, thinking, working, reading, writing, running, waiting
    case needsAttention, success, error, sleeping

    /// Rótulo em português, usado em acessibilidade e na interface.
    public var label: String {
        switch self {
        case .idle: "Tranquilo"
        case .watching: "Atento"
        case .thinking: "Pensando"
        case .working: "Trabalhando"
        case .reading: "Lendo"
        case .writing: "Escrevendo"
        case .running: "Executando"
        case .waiting: "Aguardando"
        case .needsAttention: "Precisa de você"
        case .success: "Concluído"
        case .error: "Erro"
        case .sleeping: "Dormindo"
        }
    }
}

/// Interações transitórias, sobrepostas ao estado.
public enum TucaInteraction: Equatable, Sendable {
    case none, blink, cursorLook, clickReaction, dragHover, receivingFile
}

public enum TucaStatePriority {
    /// needsAttention > error > running > writing > reading > thinking > working > success > watching > idle > sleeping.
    /// `waiting` não aparece na lista do pacote: fica entre watching e idle.
    public static let ordered: [TucaVisualState] = [
        .needsAttention, .error, .running, .writing, .reading, .thinking,
        .working, .success, .watching, .waiting, .idle, .sleeping,
    ]

    public static func rank(_ s: TucaVisualState) -> Int { ordered.firstIndex(of: s) ?? ordered.count }

    public static func highest<S: Sequence>(_ states: S) -> TucaVisualState? where S.Element == TucaVisualState {
        states.min { rank($0) < rank($1) }
    }
}

/// Tipo de atividade de uma ferramenta do Claude Code, a partir do `tool_name` do hook PreToolUse.
public enum ToolActivity: Equatable, Sendable {
    case reading, writing, running, working

    public static func classify(tool: String) -> ToolActivity {
        switch tool {
        case "Read", "Grep", "Glob", "LS", "WebFetch", "WebSearch", "NotebookRead", "BashOutput":
            return .reading
        case "Edit", "MultiEdit", "Write", "NotebookEdit":
            return .writing
        case "Bash", "KillShell", "KillBash":
            return .running
        default:
            // MCP: classifica pelo verbo no nome; na dúvida, trabalho genérico.
            if tool.hasPrefix("mcp__") {
                let l = tool.lowercased()
                if ["read", "get", "search", "list", "fetch", "query", "find"].contains(where: l.contains) { return .reading }
                if ["write", "create", "update", "edit", "insert", "delete", "upload"].contains(where: l.contains) { return .writing }
            }
            return .working
        }
    }

    public var visualState: TucaVisualState {
        switch self {
        case .reading: .reading
        case .writing: .writing
        case .running: .running
        case .working: .working
        }
    }
}

/// Fase de uma sessão do Claude Code, derivada apenas dos hooks que o HookServer recebe.
public enum SessionPhase: Equatable, Sendable {
    case started              // SessionStart
    case thinking             // UserPromptSubmit
    case tool(ToolActivity)   // PreToolUse
    case needsYou             // Notification de permissão ou pergunta
    case waitingInput         // Notification "waiting for your input" depois de concluir
    case done                 // Stop
    case failed               // PostToolUseFailure ou StopFailure
}

public struct SessionSignal: Equatable, Sendable {
    public var phase: SessionPhase
    public var since: Date
    public init(phase: SessionPhase, since: Date) {
        self.phase = phase
        self.since = since
    }
}

public enum ChatSignal: Equatable, Sendable {
    case idle
    case thinking            // pedido enviado, sem primeira saída
    case streaming           // resposta chegando
    case succeeded(Date)
    case failed(Date)
}

public struct TucaInputs: Sendable {
    public var sessions: [SessionSignal]
    public var chat: ChatSignal
    public var hovering: Bool
    public var lastActivity: Date
    public var now: Date

    public init(sessions: [SessionSignal] = [], chat: ChatSignal = .idle, hovering: Bool = false,
                lastActivity: Date = .distantPast, now: Date = Date()) {
        self.sessions = sessions
        self.chat = chat
        self.hovering = hovering
        self.lastActivity = lastActivity
        self.now = now
    }
}

/// Resolve o estado do mascote a partir do estado real do app. Não guarda estado próprio.
public enum TucaStateResolver {
    public static let successWindow: TimeInterval = 4
    public static let errorWindow: TimeInterval = 8
    public static let sleepAfter: TimeInterval = 10 * 60

    public static func candidates(_ i: TucaInputs) -> [TucaVisualState] {
        var c: [TucaVisualState] = []
        for s in i.sessions {
            let age = i.now.timeIntervalSince(s.since)
            switch s.phase {
            case .started: c.append(.watching)
            case .thinking: c.append(.thinking)
            case .tool(let a): c.append(a.visualState)
            case .needsYou: c.append(.needsAttention)
            case .waitingInput: c.append(.waiting)
            case .done: if age < successWindow { c.append(.success) }
            case .failed: if age < errorWindow { c.append(.error) }
            }
        }
        switch i.chat {
        case .idle: break
        case .thinking: c.append(.thinking)
        case .streaming: c.append(.working)
        case .succeeded(let at): if i.now.timeIntervalSince(at) < successWindow { c.append(.success) }
        case .failed(let at): if i.now.timeIntervalSince(at) < errorWindow { c.append(.error) }
        }
        if i.hovering { c.append(.watching) }
        return c
    }

    public static func resolve(_ i: TucaInputs) -> TucaVisualState {
        if let best = TucaStatePriority.highest(candidates(i)) { return best }
        return i.now.timeIntervalSince(i.lastActivity) > sleepAfter ? .sleeping : .idle
    }
}
