import Foundation
import Darwin

/// Recebe os eventos dos hooks do Claude Code por um socket Unix local.
/// Socket 0600, pasta 0700 e só aceita conexões do mesmo usuário.
final class HookServer: @unchecked Sendable {
    static let shared = HookServer()

    static var supportDir: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tuca")
    }
    static var socketPath: String { supportDir.appendingPathComponent("tuca.sock").path }

    var onPayload: (@MainActor ([String: Any]) -> Void)?

    func start() {
        let dir = Self.supportDir
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
        Thread.detachNewThread { self.run() }
    }

    private func run() {
        let path = Self.socketPath
        unlink(path)
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        guard bytes.count < MemoryLayout.size(ofValue: addr.sun_path) else { close(fd); return }
        withUnsafeMutableBytes(of: &addr.sun_path) { raw in
            raw.copyBytes(from: bytes)
            raw[bytes.count] = 0
        }
        let len = socklen_t(MemoryLayout<sockaddr_un>.size)
        let rc = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, len) }
        }
        guard rc == 0 else { close(fd); return }
        chmod(path, 0o600)
        guard listen(fd, 16) == 0 else { close(fd); return }

        while true {
            let client = accept(fd, nil, nil)
            if client < 0 { continue }
            var uid: uid_t = 0, gid: gid_t = 0
            guard getpeereid(client, &uid, &gid) == 0, uid == getuid() else {
                close(client)
                continue
            }
            DispatchQueue.global(qos: .utility).async { self.handle(client) }
        }
    }

    private func handle(_ fd: Int32) {
        var tv = timeval(tv_sec: 3, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        var data = Data()
        var buf = [UInt8](repeating: 0, count: 16_384)
        var payload: [String: Any]?
        while data.count < 2_000_000 {
            let n = recv(fd, &buf, buf.count, 0)
            if n <= 0 { break }
            data.append(buf, count: n)
            // O JSON chega inteiro em um ou mais pedaços: tenta fechar quando termina em "}".
            if let last = data.last(where: { $0 != 0x0A && $0 != 0x0D && $0 != 0x20 }), last == UInt8(ascii: "}"),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                payload = obj
                break
            }
        }
        if payload == nil {
            payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        }
        close(fd)
        guard let payload else { return }
        DispatchQueue.main.async {
            MainActor.assumeIsolated { self.onPayload?(payload) }
        }
    }
}

/// Instala e remove os hooks no ~/.claude/settings.json com backup e merge.
enum HookInstaller {
    static let events = ["SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse", "PostToolUseFailure",
                         "Notification", "Stop", "StopFailure", "SessionEnd"]

    static var scriptURL: URL { HookServer.supportDir.appendingPathComponent("tuca-hook") }
    static var settingsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/settings.json")
    }
    static var command: String { "\"\(scriptURL.path)\"" }

    static let script = """
    #!/bin/sh
    # Tuca hook relay. Sempre sai com 0: nunca bloqueia o agente.
    SOCK="$HOME/Library/Application Support/Tuca/tuca.sock"
    if [ -S "$SOCK" ]; then
      /usr/bin/nc -U -w 2 "$SOCK" >/dev/null 2>&1
    else
      cat >/dev/null
    fi
    exit 0

    """

    enum InstallError: LocalizedError {
        case invalidJSON
        case unexpected(String)
        var errorDescription: String? {
            switch self {
            case .invalidJSON: "O ~/.claude/settings.json não é um JSON válido."
            case .unexpected(let k): "O campo \"\(k)\" do ~/.claude/settings.json tem um formato inesperado."
            }
        }
    }

    static func writeScript() {
        let dir = HookServer.supportDir
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
        try? script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
    }

    static func isOurs(_ entry: Any) -> Bool {
        guard let e = entry as? [String: Any], let hs = e["hooks"] as? [[String: Any]] else { return false }
        return hs.contains { ($0["command"] as? String)?.contains("Tuca/tuca-hook") == true }
    }

    static var isInstalled: Bool {
        guard let s = try? readSettings(), let hooks = s["hooks"] as? [String: Any] else { return false }
        return events.allSatisfy { (hooks[$0] as? [Any])?.contains(where: isOurs) == true }
    }

    static func readSettings() throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else { return [:] }
        let d = try Data(contentsOf: settingsURL)
        if d.isEmpty { return [:] }
        guard let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { throw InstallError.invalidJSON }
        return o
    }

    private static func backup() throws -> URL? {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else { return nil }
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        let dst = settingsURL.deletingLastPathComponent()
            .appendingPathComponent("settings.json.tuca-bak-\(f.string(from: Date()))")
        try FileManager.default.copyItem(at: settingsURL, to: dst)
        return dst
    }

    private static func hooksDict(_ s: [String: Any]) throws -> [String: Any] {
        guard let h = s["hooks"] else { return [:] }
        guard let d = h as? [String: Any] else { throw InstallError.unexpected("hooks") }
        return d
    }

    private static func write(_ s: [String: Any]) throws {
        try FileManager.default.createDirectory(at: settingsURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        let d = try JSONSerialization.data(withJSONObject: s,
                                           options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try d.write(to: settingsURL, options: .atomic)
    }

    /// Retorna o caminho do backup criado (nil se o arquivo ainda não existia).
    static func install() throws -> URL? {
        writeScript()
        var s = try readSettings()
        var hooks = try hooksDict(s)
        for ev in events {
            var arr: [Any] = []
            if let a = hooks[ev] {
                guard let aa = a as? [Any] else { throw InstallError.unexpected("hooks.\(ev)") }
                arr = aa
            }
            arr.removeAll(where: isOurs)
            arr.append(["hooks": [["type": "command", "command": command, "timeout": 5]]])
            hooks[ev] = arr
        }
        s["hooks"] = hooks
        let bak = try backup()
        try write(s)
        return bak
    }

    static func uninstall() throws -> URL? {
        var s = try readSettings()
        var hooks = try hooksDict(s)
        for ev in events {
            guard var arr = hooks[ev] as? [Any] else { continue }
            arr.removeAll(where: isOurs)
            hooks[ev] = arr.isEmpty ? nil : arr
        }
        if hooks.isEmpty { s.removeValue(forKey: "hooks") } else { s["hooks"] = hooks }
        let bak = try backup()
        try write(s)
        return bak
    }
}
