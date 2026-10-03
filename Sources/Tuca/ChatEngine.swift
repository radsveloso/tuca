import Foundation
import SwiftUI

enum Provider: String, CaseIterable, Identifiable {
    case claude, copilot, gemini, codex, grok, workiq
    var id: String { rawValue }

    var label: String {
        switch self {
        case .claude: "Claude"
        case .copilot: "Copilot"
        case .gemini: "Gemini"
        case .codex: "ChatGPT"
        case .grok: "Grok"
        case .workiq: "M365"
        }
    }

    var binary: String {
        switch self {
        case .claude: "claude"
        case .copilot: "copilot"
        case .gemini: "gemini"
        case .codex: "codex"
        case .grok: "grok"
        case .workiq: "workiq"
        }
    }

    var installHint: String {
        switch self {
        case .claude: "npm i -g @anthropic-ai/claude-code, depois rode claude para fazer login"
        case .copilot: "npm i -g @github/copilot, depois rode copilot para fazer login"
        case .gemini: "npm i -g @google/gemini-cli, depois rode gemini e entre com sua conta Google"
        case .codex: "npm i -g @openai/codex, depois rode codex login com sua conta ChatGPT"
        case .grok: "curl -fsSL https://x.ai/cli/install.sh | bash, depois grok login (SuperGrok ou X Premium+)"
        case .workiq: "npm i -g @microsoft/workiq, depois workiq accept-eula (exige licença Microsoft 365 Copilot)"
        }
    }

    /// Provedores opcionais só aparecem quando a CLI está instalada.
    var optional: Bool { self == .workiq }

    var color: Color {
        switch self {
        case .claude: Color(red: 0.85, green: 0.47, blue: 0.34)
        case .copilot: Color(red: 0.64, green: 0.45, blue: 0.98)
        case .gemini: Color(red: 0.32, green: 0.56, blue: 1.0)
        case .codex: Color(red: 0.25, green: 0.78, blue: 0.55)
        case .grok: Color(white: 0.92)
        case .workiq: Color(red: 0.0, green: 0.62, blue: 0.95)
        }
    }
}

struct ChatMessage: Identifiable {
    enum Role { case user, assistant, error }
    let id = UUID()
    var role: Role
    var text: String
    let provider: Provider
}

/// Lê bytes de um pipe e devolve linhas completas.
final class LineBuffer {
    private var buf = Data()
    func feed(_ d: Data) -> [String] {
        buf.append(d)
        var lines: [String] = []
        while let i = buf.firstIndex(of: 0x0A) {
            lines.append(String(decoding: buf[buf.startIndex..<i], as: UTF8.self))
            buf.removeSubrange(buf.startIndex...i)
        }
        return lines
    }
    func flush() -> [String] {
        defer { buf = Data() }
        return buf.isEmpty ? [] : [String(decoding: buf, as: UTF8.self)]
    }
}

final class DataBox {
    private let lock = NSLock()
    private var data = Data()
    func set(_ d: Data) { lock.lock(); data = d; lock.unlock() }
    var string: String { lock.lock(); defer { lock.unlock() }; return String(decoding: data, as: UTF8.self) }
}

/// Conversa usando as CLIs oficiais de cada fornecedor. Cada CLI usa o login
/// da sua própria assinatura. O Tuca nunca lê nem guarda token nenhum.
@MainActor
final class ChatEngine: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    @Published var provider: Provider = .claude
    @Published private(set) var isRunning = false
    @Published private(set) var available: [Provider: String] = [:]
    @Published private(set) var revision = 0
    @Published var draft = ""

    private var process: Process?
    private var claudeSessionId: String?
    private var stopped = false

    static var workDir: URL {
        let dir = HookServer.supportDir.appendingPathComponent("chat")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func detect() {
        DispatchQueue.global(qos: .userInitiated).async {
            var found: [Provider: String] = [:]
            for p in Provider.allCases {
                if let path = ShellEnv.which(p.binary) { found[p] = path }
            }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.available = found
                    if found[self.provider] == nil,
                       let first = Provider.allCases.first(where: { found[$0] != nil }) {
                        self.provider = first
                    }
                }
            }
        }
    }

    func _inject(_ m: [ChatMessage]) { messages = m }

    func newChat() {
        guard !isRunning else { return }
        messages = []
        claudeSessionId = nil
        revision += 1
    }

    func stop() {
        stopped = true
        process?.terminate()
    }

    func send(_ raw: String) {
        let prompt = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isRunning else { return }
        let provider = self.provider
        guard let bin = available[provider] else {
            messages.append(ChatMessage(role: .error,
                text: "\(provider.label) não está instalado. No Terminal: \(provider.installHint)",
                provider: provider))
            revision += 1
            return
        }

        let history = messages
        messages.append(ChatMessage(role: .user, text: prompt, provider: provider))
        let reply = ChatMessage(role: .assistant, text: "", provider: provider)
        messages.append(reply)
        let replyId = reply.id
        revision += 1
        isRunning = true
        stopped = false

        let p = Process()
        p.executableURL = URL(fileURLWithPath: bin)
        p.currentDirectoryURL = Self.workDir
        p.environment = ShellEnv.environment
        var lastMessageFile: URL?

        switch provider {
        case .claude:
            var args = ["-p"]
            if let sid = claudeSessionId {
                args += [prompt, "--resume", sid]
            } else {
                args += [Self.withHistory(prompt, history)]
            }
            // Modo enxuto: sem hooks, plugins e MCPs do usuario (de 80 s para 2 s), mantendo o login OAuth.
            args += ["--output-format", "stream-json", "--verbose", "--include-partial-messages",
                     "--strict-mcp-config", "--setting-sources", "local", "--disable-slash-commands"]
            p.arguments = args
        case .copilot:
            p.arguments = ["-p", Self.withHistory(prompt, history), "-s", "--no-color", "--model", "auto"]
        case .gemini, .grok:
            p.arguments = ["-p", Self.withHistory(prompt, history)]
        case .workiq:
            p.arguments = ["ask", "-q", Self.withHistory(prompt, history)]
        case .codex:
            let f = FileManager.default.temporaryDirectory
                .appendingPathComponent("tuca-codex-\(UUID().uuidString).txt")
            lastMessageFile = f
            p.arguments = ["exec", "--skip-git-repo-check", "--color", "never",
                           "--output-last-message", f.path, Self.withHistory(prompt, history)]
        }

        let out = Pipe(), err = Pipe()
        p.standardOutput = out
        p.standardError = err
        p.standardInput = FileHandle.nullDevice

        do { try p.run() } catch {
            finish(replyId, fallback: "Não consegui iniciar \(provider.binary): \(error.localizedDescription)", isError: true)
            return
        }
        process = p

        let errBox = DataBox()
        let errHandle = err.fileHandleForReading
        let errDone = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            errBox.set(errHandle.readDataToEndOfFile())
            errDone.signal()
        }

        let outHandle = out.fileHandleForReading
        let claudeState = ClaudeStreamState()
        DispatchQueue.global().async { [weak self] in
            let lines = LineBuffer()
            var raw = Data()
            while true {
                let data = outHandle.availableData
                if data.isEmpty { break }
                switch provider {
                case .claude:
                    let ls = lines.feed(data)
                    if !ls.isEmpty {
                        DispatchQueue.main.async {
                            MainActor.assumeIsolated { self?.handleClaude(ls, replyId: replyId, state: claudeState) }
                        }
                    }
                case .copilot, .gemini, .grok, .workiq:
                    raw.append(data)
                    let text = String(decoding: raw, as: UTF8.self).strippingANSI
                    DispatchQueue.main.async {
                        MainActor.assumeIsolated { self?.setText(replyId, text) }
                    }
                case .codex:
                    break
                }
            }
            let rest = lines.flush()
            p.waitUntilExit()
            _ = errDone.wait(timeout: .now() + 2)
            let status = p.terminationStatus
            let errText = errBox.string.strippingANSI.trimmingCharacters(in: .whitespacesAndNewlines)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self else { return }
                    if provider == .claude, !rest.isEmpty {
                        self.handleClaude(rest, replyId: replyId, state: claudeState)
                    }
                    if provider == .codex, let f = lastMessageFile {
                        if let t = try? String(contentsOf: f, encoding: .utf8) {
                            self.setText(replyId, t.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                        try? FileManager.default.removeItem(at: f)
                    }
                    let fallback: String
                    if self.stopped {
                        fallback = "(interrompido)"
                    } else if status == 0 {
                        fallback = "(sem resposta)"
                    } else {
                        fallback = "Erro (código \(status)). " + String(errText.suffix(700))
                    }
                    self.finish(replyId, fallback: fallback, isError: status != 0 && !self.stopped)
                }
            }
        }
    }

    // MARK: - Helpers

    private static func withHistory(_ prompt: String, _ history: [ChatMessage]) -> String {
        let turns = history.filter { $0.role != .error && !$0.text.isEmpty }.suffix(8)
        guard !turns.isEmpty else { return prompt }
        var s = "Contexto: conversa anterior com o usuário.\n\n"
        for m in turns {
            s += (m.role == .user ? "Usuário: " : "Assistente: ") + m.text + "\n\n"
        }
        s += "Nova mensagem do usuário:\n" + prompt
        return s
    }

    final class ClaudeStreamState {
        var sawDelta = false
    }

    private func handleClaude(_ lines: [String], replyId: UUID, state: ClaudeStreamState) {
        for line in lines {
            guard let d = line.data(using: .utf8),
                  let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { continue }
            if let sid = o["session_id"] as? String { claudeSessionId = sid }
            switch o["type"] as? String {
            case "stream_event":
                guard let ev = o["event"] as? [String: Any] else { continue }
                let evType = ev["type"] as? String
                if evType == "content_block_start",
                   let block = ev["content_block"] as? [String: Any],
                   block["type"] as? String == "text",
                   !text(of: replyId).isEmpty {
                    append(replyId, "\n\n")
                }
                if evType == "content_block_delta",
                   let delta = ev["delta"] as? [String: Any],
                   delta["type"] as? String == "text_delta",
                   let t = delta["text"] as? String {
                    state.sawDelta = true
                    append(replyId, t)
                }
            case "assistant":
                guard !state.sawDelta,
                      let msg = o["message"] as? [String: Any],
                      let content = msg["content"] as? [[String: Any]] else { continue }
                for b in content where b["type"] as? String == "text" {
                    append(replyId, b["text"] as? String ?? "")
                }
            case "result":
                if text(of: replyId).isEmpty, let r = o["result"] as? String {
                    setText(replyId, r)
                }
            default:
                continue
            }
        }
    }

    private func index(_ id: UUID) -> Int? { messages.firstIndex { $0.id == id } }

    private func text(of id: UUID) -> String {
        index(id).map { messages[$0].text } ?? ""
    }

    private func append(_ id: UUID, _ t: String) {
        guard let i = index(id) else { return }
        messages[i].text += t
        revision += 1
    }

    private func setText(_ id: UUID, _ t: String) {
        guard let i = index(id) else { return }
        messages[i].text = t
        revision += 1
    }

    private func finish(_ id: UUID, fallback: String, isError: Bool) {
        if let i = index(id), messages[i].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messages[i].text = fallback
            if isError { messages[i].role = .error }
        }
        isRunning = false
        process = nil
        revision += 1
    }
}
