import AppKit
import SwiftUI
import TucaCharacter
import TucaCore

// O Tuca do notch é o Character Engine 3.0 (módulo TucaCharacter): rig em Core Animation
// montado com camadas derivadas do master aprovado. Este arquivo só liga o motor ao app:
// o estado vem do TucaCore (sessões, chat, notch) e as interações do NotchController.

// MARK: - Entrada compartilhada

/// Fonte única do que o personagem precisa saber a cada quadro.
final class TucaFX {
    static let shared = TucaFX()

    var mouse: CGPoint = .zero
    var anchor: CGPoint = .zero
    var clickAt: Date = .distantPast
    var receivedAt: Date = .distantPast
    var dragHover = false
    /// Fornecido pelo app: entradas do resolvedor a partir das sessões, do chat e do notch.
    var inputs: ((Date) -> TucaInputs)?

    func state(at now: Date) -> TucaVisualState {
        TucaStateResolver.resolve(inputs?(now) ?? TucaInputs(now: now))
    }
}

// MARK: - Personagem no notch

/// O Tuca vivo dentro do SwiftUI do notch.
struct TucaCharacterSlot: NSViewRepresentable {
    /// Folga em volta do personagem. No notch recolhido quase nenhuma.
    var margins = CGSize(width: 1.18, height: 1.32)

    final class Coordinator {
        var lastReceived = Date.distantPast
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> TucaCharacterView {
        let v = TucaCharacterView(frame: .zero)
        v.fitMargins = margins
        v.acceptsFileDrops = false          // quem anexa o arquivo é o notch
        let coord = context.coordinator
        coord.lastReceived = TucaFX.shared.receivedAt
        v.onTick = { view in
            let fx = TucaFX.shared
            view.state = fx.state(at: Date())
            view.dragHovering = fx.dragHover
            if fx.receivedAt > coord.lastReceived {
                coord.lastReceived = fx.receivedAt
                view.receiveFile()
            }
        }
        return v
    }

    func updateNSView(_ v: TucaCharacterView, context: Context) {
        if v.fitMargins != margins { v.fitMargins = margins }
    }
}

// MARK: - Rótulo de estado

/// Rótulo de estado (texto + símbolo), para não depender só de cor.
struct TucaStateLabel: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { tl in
            let s = TucaFX.shared.state(at: tl.date)
            HStack(spacing: 4) {
                Image(systemName: s.symbol).font(.system(size: 10, weight: .semibold))
                Text(s.label).font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(s.tint)
            .accessibilityElement(children: .combine)
        }
    }
}

extension TucaVisualState {
    var symbol: String {
        switch self {
        case .idle: "circle"
        case .watching: "eye.fill"
        case .thinking: "ellipsis.bubble.fill"
        case .working: "gearshape.fill"
        case .reading: "book.fill"
        case .writing: "pencil"
        case .running: "terminal.fill"
        case .waiting: "hourglass"
        case .needsAttention: "exclamationmark.circle.fill"
        case .success: "checkmark.circle.fill"
        case .error: "xmark.octagon.fill"
        case .sleeping: "moon.zzz.fill"
        }
    }

    var tint: Color {
        switch self {
        case .needsAttention, .error: Color(red: 1, green: 0.36, blue: 0.32)
        case .success: Color(red: 0.32, green: 0.86, blue: 0.52)
        case .running, .writing, .reading, .working: Color(red: 1, green: 0.6, blue: 0.2)
        case .thinking: Color(red: 0.082, green: 0.651, blue: 1.0)
        default: Color.secondary
        }
    }
}
