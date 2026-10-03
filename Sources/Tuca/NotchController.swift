import AppKit
import SwiftUI
import TucaCore

final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

struct NotchGeometry {
    let screen: NSScreen

    static func current() -> NotchGeometry {
        let s = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main ?? NSScreen.screens[0]
        return NotchGeometry(screen: s)
    }

    var hasNotch: Bool { screen.safeAreaInsets.top > 0 }

    var notchWidth: CGFloat {
        if hasNotch, let l = screen.auxiliaryTopLeftArea, let r = screen.auxiliaryTopRightArea {
            return screen.frame.width - l.width - r.width + 4
        }
        return 190
    }

    var notchHeight: CGFloat {
        hasNotch ? screen.safeAreaInsets.top : max(24, screen.frame.maxY - screen.visibleFrame.maxY)
    }
}

enum IslandTab: Hashable { case sessions, chat }

@MainActor
final class NotchController: ObservableObject {
    @Published private(set) var expanded = false
    @Published var tab: IslandTab = .sessions
    @Published var pinned = false
    @Published var dropTargeted = false {
        didSet { TucaFX.shared.dragHover = dropTargeted }
    }
    private var lastDropChange = -1
    @Published private(set) var geo = NotchGeometry.current()

    let store: SessionStore
    let chat: ChatEngine
    var onInstallHooks: (() -> Void)?

    static let ear: CGFloat = 64
    static let expandedSize = CGSize(width: 580, height: 360)

    private var panel: NotchPanel!
    private var monitors: [Any] = []
    private var collapseWork: DispatchWorkItem?

    init(store: SessionStore, chat: ChatEngine) {
        self.store = store
        self.chat = chat
    }

    var hasActivity: Bool { !store.sessions.isEmpty || chat.isRunning }

    var shapeSize: CGSize {
        if expanded {
            return CGSize(width: Self.expandedSize.width, height: geo.notchHeight + Self.expandedSize.height)
        }
        if hasActivity {
            return CGSize(width: geo.notchWidth + 2 * Self.ear, height: geo.notchHeight)
        }
        return geo.hasNotch ? CGSize(width: geo.notchWidth, height: geo.notchHeight) : CGSize(width: 160, height: 5)
    }

    func show() {
        let p = NotchPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                           backing: .buffered, defer: false)
        p.isFloatingPanel = true
        p.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = false
        p.isMovable = false
        p.hidesOnDeactivate = false
        p.becomesKeyOnlyIfNeeded = false
        p.acceptsMouseMovedEvents = true
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        let host = NSHostingView(rootView: RootView(c: self, store: store, chat: chat))
        host.sizingOptions = []
        p.contentView = host
        panel = p
        reposition()
        p.ignoresMouseEvents = true
        p.orderFrontRegardless()

        let handler: (NSEvent) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.mouseMoved() }
        }
        if let g = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: handler) {
            monitors.append(g)
        }
        if let l = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: { e in
            handler(e)
            return e
        }) {
            monitors.append(l)
        }
    }

    func reposition() {
        geo = .current()
        guard let panel else { return }
        let s = geo.screen.frame
        let w = Self.expandedSize.width + 60
        let h = geo.notchHeight + Self.expandedSize.height + 40
        panel.setFrame(NSRect(x: s.midX - w / 2, y: s.maxY - h, width: w, height: h), display: true)
    }

    private var shapeRectOnScreen: NSRect {
        let s = geo.screen.frame
        let sz = shapeSize
        return NSRect(x: s.midX - sz.width / 2, y: s.maxY - sz.height, width: sz.width, height: sz.height)
    }

    private func mouseInside(margin: CGFloat) -> Bool {
        var r = shapeRectOnScreen.insetBy(dx: -margin, dy: -margin)
        r.size.height += 4  // inclui a borda de cima da tela
        return r.contains(NSEvent.mouseLocation)
    }

    private func mouseMoved() {
        let fx = TucaFX.shared
        fx.mouse = NSEvent.mouseLocation
        fx.anchor = CGPoint(x: geo.screen.frame.midX, y: geo.screen.frame.maxY - geo.notchHeight / 2)
        if expanded {
            if mouseInside(margin: 14) {
                collapseWork?.cancel()
                collapseWork = nil
            } else if !pinned && collapseWork == nil {
                scheduleCollapse(after: 0.35)
            }
        } else if isFileDrag && mouseInside(margin: 40) {
            tab = .chat
            expand()
        } else if mouseInside(margin: geo.hasNotch ? 0 : 6) {
            expand()
        }
    }

    /// Arraste de arquivo em andamento (vindo do Finder, da área de trabalho etc.).
    private var isFileDrag: Bool {
        guard NSEvent.pressedMouseButtons & 1 == 1 else { return false }
        let pb = NSPasteboard(name: .drag)
        return pb.changeCount != lastDropChange && (pb.types?.contains(.fileURL) ?? false)
    }

    func handleDrop(_ urls: [URL]) {
        lastDropChange = NSPasteboard(name: .drag).changeCount
        dropTargeted = false
        TucaFX.shared.receivedAt = Date()
        chat.attach(urls)
        tab = .chat
        expand()
        NSSound(named: "Pop")?.play()
        panel.makeKey()
    }

    func expand() {
        collapseWork?.cancel()
        collapseWork = nil
        guard !expanded else { return }
        expanded = true
        panel.ignoresMouseEvents = false
    }

    func collapse() {
        collapseWork?.cancel()
        collapseWork = nil
        guard expanded else { return }
        expanded = false
        panel.ignoresMouseEvents = true
        if panel.isKeyWindow { panel.resignKey() }
    }

    func _setExpanded(_ v: Bool) { expanded = v }

    func toggle() { expanded ? collapse() : expand() }

    private func scheduleCollapse(after delay: TimeInterval) {
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self, !self.pinned, !self.mouseInside(margin: 14) else {
                    self?.collapseWork = nil
                    return
                }
                self.collapse()
            }
        }
        collapseWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    /// Uma sessão precisa de você: abre, toca um som e fecha sozinho se você não passar o mouse.
    func attention() {
        tab = .sessions
        expand()
        NSSound(named: "Glass")?.play()
        scheduleCollapse(after: 8)
    }

    func openChat() {
        tab = .chat
        expand()
        panel.makeKey()
    }
}
