// Verificações determinísticas do TucaCore. O Command Line Tools não inclui
// XCTest nem swift-testing, então rodam como executável: `swift run TucaCoreChecks`.
import Foundation

nonisolated(unsafe) var failures = 0
nonisolated(unsafe) var checks = 0

func expect(_ ok: @autoclosure () -> Bool, _ file: StaticString = #file, line: UInt = #line) {
    checks += 1
    if !ok() { failures += 1; print("FALHOU linha \(line)") }
}

import Foundation
import TucaCore

private let t0 = Date(timeIntervalSinceReferenceDate: 1_000_000)

private func session(_ p: SessionPhase, ago: TimeInterval = 0) -> SessionSignal {
    SessionSignal(phase: p, since: t0.addingTimeInterval(-ago))
}

func prioridadeSegueOPacote() {
    let expected: [TucaVisualState] = [.needsAttention, .error, .running, .writing, .reading, .thinking,
                                       .working, .success, .watching, .waiting, .idle, .sleeping]
    expect(TucaStatePriority.ordered == expected)
    expect(Set(TucaStatePriority.ordered) == Set(TucaVisualState.allCases))
}

func classificaFerramentas() {
    expect(ToolActivity.classify(tool: "Read") == .reading)
    expect(ToolActivity.classify(tool: "Grep") == .reading)
    expect(ToolActivity.classify(tool: "WebSearch") == .reading)
    expect(ToolActivity.classify(tool: "Edit") == .writing)
    expect(ToolActivity.classify(tool: "Write") == .writing)
    expect(ToolActivity.classify(tool: "Bash") == .running)
    expect(ToolActivity.classify(tool: "Task") == .working)
    expect(ToolActivity.classify(tool: "mcp__github__search_issues") == .reading)
    expect(ToolActivity.classify(tool: "mcp__notion__create_page") == .writing)
    expect(ToolActivity.classify(tool: "Desconhecida") == .working)
}

func atencaoVenceTudo() {
    let i = TucaInputs(sessions: [session(.tool(.running)), session(.needsYou), session(.failed)],
                       chat: .streaming, now: t0)
    expect(TucaStateResolver.resolve(i) == .needsAttention)
}

func ordemEntreFerramentas() {
    let i = TucaInputs(sessions: [session(.tool(.reading)), session(.tool(.writing)), session(.tool(.running))], now: t0)
    expect(TucaStateResolver.resolve(i) == .running)
    let j = TucaInputs(sessions: [session(.tool(.reading)), session(.thinking)], now: t0)
    expect(TucaStateResolver.resolve(j) == .reading)
}

func sucessoEhTransitorio() {
    expect(TucaStateResolver.resolve(TucaInputs(sessions: [session(.done, ago: 1)], now: t0)) == .success)
    let depois = TucaInputs(sessions: [session(.done, ago: 30)], lastActivity: t0.addingTimeInterval(-30), now: t0)
    expect(TucaStateResolver.resolve(depois) == .idle)
}

func erroEhTransitorio() {
    expect(TucaStateResolver.resolve(TucaInputs(sessions: [session(.failed, ago: 2)], now: t0)) == .error)
    expect(TucaStateResolver.resolve(TucaInputs(sessions: [session(.failed, ago: 60)], lastActivity: t0, now: t0)) == .idle)
}

func chat() {
    expect(TucaStateResolver.resolve(TucaInputs(chat: .thinking, now: t0)) == .thinking)
    expect(TucaStateResolver.resolve(TucaInputs(chat: .streaming, now: t0)) == .working)
    expect(TucaStateResolver.resolve(TucaInputs(chat: .succeeded(t0.addingTimeInterval(-1)), now: t0)) == .success)
    expect(TucaStateResolver.resolve(TucaInputs(chat: .failed(t0.addingTimeInterval(-1)), now: t0)) == .error)
    expect(TucaStateResolver.resolve(TucaInputs(chat: .failed(t0.addingTimeInterval(-60)), lastActivity: t0, now: t0)) == .idle)
}

func sessaoNovaObserva() {
    expect(TucaStateResolver.resolve(TucaInputs(sessions: [session(.started)], now: t0)) == .watching)
    expect(TucaStateResolver.resolve(TucaInputs(sessions: [session(.waitingInput)], now: t0)) == .waiting)
}

func dormeEAcordaComHover() {
    let longe = t0.addingTimeInterval(-TucaStateResolver.sleepAfter - 1)
    expect(TucaStateResolver.resolve(TucaInputs(lastActivity: longe, now: t0)) == .sleeping)
    expect(TucaStateResolver.resolve(TucaInputs(hovering: true, lastActivity: longe, now: t0)) == .watching)
    expect(TucaStateResolver.resolve(TucaInputs(lastActivity: t0, now: t0)) == .idle)
}

let all: [(String, () -> Void)] = [
    ("prioridadeSegueOPacote", prioridadeSegueOPacote),
    ("classificaFerramentas", classificaFerramentas),
    ("atencaoVenceTudo", atencaoVenceTudo),
    ("ordemEntreFerramentas", ordemEntreFerramentas),
    ("sucessoEhTransitorio", sucessoEhTransitorio),
    ("erroEhTransitorio", erroEhTransitorio),
    ("chat", chat),
    ("sessaoNovaObserva", sessaoNovaObserva),
    ("dormeEAcordaComHover", dormeEAcordaComHover),
]
for (name, run) in all {
    let before = failures
    run()
    print((failures == before ? "ok    " : "FALHA ") + name)
}
print("\(checks) verificações, \(failures) falhas")
exit(failures == 0 ? 0 : 1)
