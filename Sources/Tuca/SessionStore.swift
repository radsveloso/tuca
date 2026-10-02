import Foundation
import SwiftUI

enum Mood { case idle, working, attention, done }

enum SessionState {
    case idle, working, needsYou, done

    var label: String {
        switch self {
        case .idle: "ociosa"
        case .working: "trabalhando"
        case .needsYou: "precisa de você"
        case .done: "concluída"
        }
    }

    var color: Color {
        switch self {
        case .idle: .gray
        case .working: .orange
        case .needsYou: Color(red: 1, green: 0.32, blue: 0.3)
        case .done: Color(red: 0.3, green: 0.85, blue: 0.5)
        }
    }
}

struct AgentSession: Identifiable {
    let id: String
    var project: String
    var cwd: String
    var state: SessionState
    var detail: String
    var updated: Date
}

@MainActor
final class SessionStore: ObservableObject {
    static let shared = SessionStore()

    @Published private(set) var sessions: [AgentSession] = []
    @Published var hooksInstalled = HookInstaller.isInstalled

    var onAttention: (() -> Void)?
    var onDone: (() -> Void)?
    private var timer: Timer?

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.prune() }
        }
    }

    func mood(chatRunning: Bool) -> Mood {
        if sessions.contains(where: { $0.state == .needsYou }) { return .attention }
        if chatRunning || sessions.contains(where: { $0.state == .working }) { return .working }
        if sessions.contains(where: { $0.state == .done }) { return .done }
        return .idle
    }

    var workingCount: Int { sessions.filter { $0.state == .working }.count }

    func setSessionsForTesting(_ s: [AgentSession]) { sessions = s }

    func remove(_ id: String) { sessions.removeAll { $0.id == id } }

    func ingest(_ p: [String: Any]) {
        let event = p["hook_event_name"] as? String ?? ""
        guard let sid = p["session_id"] as? String else { return }
        let cwd = p["cwd"] as? String ?? ""
        // Ignora as conversas do proprio chat do Tuca.
        if cwd.hasPrefix(HookServer.supportDir.path) { return }

        switch event {
        case "SessionStart":
            upsert(sid, cwd) { $0.state = .idle; $0.detail = "Sessão iniciada" }
        case "UserPromptSubmit":
            let prompt = (p["prompt"] as? String ?? "").oneLine(90)
            upsert(sid, cwd) { $0.state = .working; $0.detail = prompt.isEmpty ? "Pensando…" : "› " + prompt }
        case "PreToolUse":
            let d = Self.describe(tool: p["tool_name"] as? String ?? "Tool",
                                  input: p["tool_input"] as? [String: Any] ?? [:])
            upsert(sid, cwd) { $0.state = .working; $0.detail = d }
        case "PostToolUse", "PostToolUseFailure":
            upsert(sid, cwd) { $0.state = .working }
        case "Notification":
            var msg = p["message"] as? String ?? "Precisa de você"
            let isPermission = msg.localizedCaseInsensitiveContains("permission")
            if msg.hasPrefix("Claude needs your permission to use ") {
                msg = "Pede permissão para usar " + msg.dropFirst("Claude needs your permission to use ".count)
            } else if msg.localizedCaseInsensitiveContains("waiting for your input") {
                msg = "Esperando sua resposta"
            }
            var alert = false
            upsert(sid, cwd) { s in
                if isPermission || s.state != .done {
                    s.state = .needsYou
                    s.detail = msg
                    alert = true
                }
            }
            if alert { onAttention?() }
        case "Stop":
            upsert(sid, cwd) { $0.state = .done; $0.detail = "Concluído, sua vez" }
            onDone?()
        case "SessionEnd":
            remove(sid)
        default:
            break
        }
    }

    private func upsert(_ id: String, _ cwd: String, _ mutate: (inout AgentSession) -> Void) {
        if let i = sessions.firstIndex(where: { $0.id == id }) {
            mutate(&sessions[i])
            sessions[i].updated = Date()
            if !cwd.isEmpty { sessions[i].cwd = cwd; sessions[i].project = Self.projectName(cwd) }
        } else {
            var s = AgentSession(id: id, project: Self.projectName(cwd), cwd: cwd,
                                 state: .idle, detail: "", updated: Date())
            mutate(&s)
            sessions.insert(s, at: 0)
        }
    }

    private func prune() {
        let now = Date()
        sessions.removeAll { s in
            let age = now.timeIntervalSince(s.updated)
            return (s.state == .done && age > 20 * 60) || age > 90 * 60
        }
    }

    static func projectName(_ cwd: String) -> String {
        cwd.isEmpty ? "Claude Code" : URL(fileURLWithPath: cwd).lastPathComponent
    }

    static func describe(tool: String, input: [String: Any]) -> String {
        func str(_ k: String) -> String { (input[k] as? String) ?? "" }
        func file(_ k: String) -> String { URL(fileURLWithPath: str(k)).lastPathComponent }
        switch tool {
        case "Bash": return "$ " + str("command").oneLine(90)
        case "Read": return "Lendo " + file("file_path")
        case "Edit", "MultiEdit": return "Editando " + file("file_path")
        case "Write": return "Escrevendo " + file("file_path")
        case "NotebookEdit": return "Editando " + file("notebook_path")
        case "Grep": return "Buscando \"" + str("pattern").oneLine(50) + "\""
        case "Glob": return "Procurando " + str("pattern").oneLine(60)
        case "WebFetch": return "Abrindo " + str("url").oneLine(70)
        case "WebSearch": return "Pesquisando \"" + str("query").oneLine(60) + "\""
        case "Task", "Agent": return "Subagente: " + str("description").oneLine(70)
        case "TodoWrite": return "Atualizando a lista de tarefas"
        default:
            if tool.hasPrefix("mcp__") {
                return "MCP: " + tool.components(separatedBy: "__").dropFirst().joined(separator: " › ")
            }
            return tool
        }
    }
}
