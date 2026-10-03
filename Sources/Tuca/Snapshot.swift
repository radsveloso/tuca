import AppKit
import SwiftUI
import TucaCharacter
import TucaCore

/// Modo de verificação: `Tuca --snapshot <pasta>` renderiza as telas em PNG e sai.
@MainActor
enum Snapshot {
    static func run(dir: String) {
        _ = NSApplication.shared
        let store = SessionStore()
        let chat = ChatEngine()
        let c = NotchController(store: store, chat: chat)
        store._inject([
            AgentSession(id: "a", project: "floranima", cwd: "", state: .needsYou,
                         detail: "Pede permissão para usar Bash", updated: Date().addingTimeInterval(-40), phase: .needsYou),
            AgentSession(id: "b", project: "menteo", cwd: "", state: .working,
                         detail: "$ npm run test -- checkout", updated: Date(), phase: .tool(.running)),
            AgentSession(id: "c", project: "embraer-tc", cwd: "", state: .done,
                         detail: "Concluído, sua vez", updated: Date().addingTimeInterval(-600)),
        ])
        chat._inject([
            ChatMessage(role: .user, text: "Resume o que mudou no checkout", provider: .claude),
            ChatMessage(role: .assistant, text: "O checkout agora valida o **CPF** antes de criar a sessão do Stripe e mostra o erro inline.", provider: .claude),
            ChatMessage(role: .user, text: "E no Copilot, qual seria o teste?", provider: .copilot),
            ChatMessage(role: .assistant, text: "", provider: .copilot),
        ])

        func render(_ name: String) {
            let view = RootView(c: c, store: store, chat: chat)
                .frame(width: 700, height: 460)
                .background(Color(white: 0.78))
            let r = ImageRenderer(content: view)
            r.scale = 2
            if let img = r.nsImage, let tiff = img.tiffRepresentation,
               let rep = NSBitmapImageRep(data: tiff),
               let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent(name + ".png"))
            }
        }
        TucaFX.shared.inputs = { now in
            MainActor.assumeIsolated {
                TucaInputs(sessions: store.signals, chat: chat.signal, hovering: c.expanded, lastActivity: now, now: now)
            }
        }

        func save<V: View>(_ v: V, _ name: String) {
            let r = ImageRenderer(content: v)
            r.scale = 2
            if let img = r.nsImage, let tiff = img.tiffRepresentation,
               let rep = NSBitmapImageRep(data: tiff),
               let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent(name + ".png"))
            }
        }

        render("1-collapsed")
        c._setExpanded(true)
        c.tab = .sessions
        render("2-sessions")
        c.tab = .chat
        render("3-chat")
    }
}

extension SessionStore {
    func _inject(_ s: [AgentSession]) { setSessionsForTesting(s) }
}
