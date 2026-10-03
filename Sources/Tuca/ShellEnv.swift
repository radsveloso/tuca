import Foundation

/// Apps abertos pelo Finder não herdam o PATH do terminal (nvm, Homebrew).
/// Lemos o PATH real do shell de login uma vez e usamos para achar as CLIs.
enum ShellEnv {
    static let path: String = {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        var result = ""
        let p = Process()
        p.executableURL = URL(fileURLWithPath: shell)
        p.arguments = ["-ilc", "printf '__TUCA__%s__TUCA__' \"$PATH\""]
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice
        p.standardInput = FileHandle.nullDevice
        do {
            try p.run()
            let deadline = Date().addingTimeInterval(6)
            while p.isRunning && Date() < deadline { usleep(20_000) }
            if p.isRunning { p.terminate() }
            let s = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            if let a = s.range(of: "__TUCA__"),
               let b = s.range(of: "__TUCA__", range: a.upperBound..<s.endIndex) {
                result = String(s[a.upperBound..<b.lowerBound])
            }
        } catch {}
        var parts = result.split(separator: ":").map(String.init)
        let home = NSHomeDirectory()
        for extra in ["/opt/homebrew/bin", "/usr/local/bin", "\(home)/.local/bin", "\(home)/.grok/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]
        where !parts.contains(extra) { parts.append(extra) }
        return parts.joined(separator: ":")
    }()

    static func which(_ name: String) -> String? {
        for dir in path.split(separator: ":") {
            let full = "\(dir)/\(name)"
            if FileManager.default.isExecutableFile(atPath: full) { return full }
        }
        return nil
    }

    static var environment: [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = path
        env["NO_COLOR"] = "1"
        env["TERM"] = "dumb"
        return env
    }
}

extension String {
    func oneLine(_ max: Int) -> String {
        let s = replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
        return s.count > max ? String(s.prefix(max)) + "…" : s
    }

    var strippingANSI: String {
        replacingOccurrences(of: "\u{1B}\\[[0-9;?]*[A-Za-z]", with: "", options: .regularExpression)
    }
}
