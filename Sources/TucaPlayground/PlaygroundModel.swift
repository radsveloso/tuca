import AppKit
import Combine
import TucaCharacter
import TucaCore

enum MotionMode: String, CaseIterable, Identifiable {
    case system = "Sistema", on = "Reduzido", off = "Normal"
    var id: String { rawValue }
    var override: Bool? {
        switch self {
        case .system: nil
        case .on: true
        case .off: false
        }
    }
}

enum Backdrop: String, CaseIterable, Identifiable {
    case notch = "Notch", dark = "Escuro", light = "Claro"
    var id: String { rawValue }
    var color: NSColor {
        switch self {
        case .notch: .black
        case .dark: NSColor(white: 0.13, alpha: 1)
        case .light: NSColor(white: 0.86, alpha: 1)
        }
    }
}

/// Estado do Playground. Todas as vistas do personagem obedecem a ele.
@MainActor
final class PlaygroundModel: ObservableObject {
    @Published var state: TucaVisualState = .idle { didSet { apply() } }
    @Published var size: Double = 256
    @Published var motion: MotionMode = .system { didSet { apply() } }
    @Published var followCursor = true { didSet { apply() } }
    @Published var hoverSim = false { didSet { apply() } }
    @Published var dragSim = false { didSet { apply() } }
    @Published var backdrop: Backdrop = .notch
    @Published var diagnostics = ""
    @Published var touring = false
    @Published var lastDrop = ""

    static let sizes: [Double] = [24, 32, 48, 64, 96, 128, 256]

    private var views: [WeakView] = []
    private var timer: Timer?
    private var tourWork: [DispatchWorkItem] = []

    private struct WeakView { weak var view: TucaCharacterView? }

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let main = self.views.first?.view else { return }
                self.diagnostics = main.diagnostics
            }
        }
    }

    func register(_ v: TucaCharacterView) {
        views.removeAll { $0.view == nil }
        views.append(WeakView(view: v))
        v.onWake = { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.state == .sleeping else { return }
                self.state = .idle
            }
        }
        v.onDropFiles = { [weak self] urls in
            MainActor.assumeIsolated { self?.lastDrop = urls.map(\.lastPathComponent).joined(separator: ", ") }
        }
        configure(v)
    }

    private var all: [TucaCharacterView] { views.compactMap(\.view) }

    func configure(_ v: TucaCharacterView) {
        v.state = state
        v.reduceMotionOverride = motion.override
        v.followsCursor = followCursor
        if hoverSim { v.hovering = true }
        v.dragHovering = dragSim
    }

    private func apply() { all.forEach(configure) }

    // Interações manuais
    func blink() { all.forEach { $0.blink() } }
    func click() { all.forEach { $0.click() } }
    func multiClick() {
        for i in 0..<4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.18) { [weak self] in
                MainActor.assumeIsolated { self?.click() }
            }
        }
    }
    func receiveFile() {
        dragSim = false
        all.forEach { $0.receiveFile() }
    }
    func wake() {
        if state != .sleeping { state = .sleeping }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            MainActor.assumeIsolated { self?.all.forEach { $0.wakeUp() } }
        }
    }

    /// Pensando, lendo, escrevendo e sucesso: a sequência do teste de aceitação.
    func tour() {
        tourWork.forEach { $0.cancel() }
        touring = true
        let steps: [TucaVisualState] = [.thinking, .reading, .writing, .success, .idle]
        for (i, s) in steps.enumerated() {
            let w = DispatchWorkItem { [weak self] in
                MainActor.assumeIsolated {
                    self?.state = s
                    if i == steps.count - 1 { self?.touring = false }
                }
            }
            tourWork.append(w)
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 3.0, execute: w)
        }
    }
}
