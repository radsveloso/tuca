import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var controller: NotchController!
    private var statusItem: NSStatusItem!
    private let store = SessionStore.shared
    private let chat = ChatEngine()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        HookInstaller.writeScript()
        AttachmentStore.purgeOld()

        controller = NotchController(store: store, chat: chat)
        controller.onInstallHooks = { [weak self] in self?.installHooks() }
        controller.show()

        store.onAttention = { [weak self] in self?.controller.attention() }
        store.onDone = { NSSound(named: "Pop")?.play() }

        HookServer.shared.onPayload = { [weak self] p in self?.store.ingest(p) }
        HookServer.shared.start()

        chat.detect()
        setupStatusItem()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.controller.reposition() }
        }
    }

    // MARK: - Barra de menus

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "bird.fill", accessibilityDescription: "Tuca")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        add(menu, "Abrir sessões", #selector(openSessions))
        add(menu, "Abrir chat", #selector(openChat))
        menu.addItem(.separator())
        if HookInstaller.isInstalled {
            add(menu, "Remover hooks do Claude Code", #selector(uninstallHooks))
        } else {
            add(menu, "Instalar hooks do Claude Code…", #selector(installHooksAction))
        }
        let login = add(menu, "Abrir ao iniciar o Mac", #selector(toggleLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(.separator())
        add(menu, "Sair do Tuca", #selector(quit), key: "q")
    }

    @discardableResult
    private func add(_ menu: NSMenu, _ title: String, _ sel: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: sel, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
        return item
    }

    @objc private func openSessions() { controller.tab = .sessions; controller.expand() }
    @objc private func openChat() { controller.openChat() }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func installHooksAction() { installHooks() }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            info("Não foi possível alterar", error.localizedDescription)
        }
    }

    // MARK: - Hooks

    func installHooks() {
        controller.collapse()
        NSApp.activate()
        let a = NSAlert()
        a.messageText = "Instalar hooks do Claude Code?"
        a.informativeText = """
        O Tuca vai adicionar \(HookInstaller.events.count) hooks ao ~/.claude/settings.json para mostrar suas sessões no notch.

        • Um backup do arquivo é criado antes.
        • Seus hooks e configurações atuais são mantidos.
        • Se o Tuca estiver fechado, o hook sai na hora e o Claude Code segue normal.
        """
        a.addButton(withTitle: "Instalar")
        a.addButton(withTitle: "Cancelar")
        guard a.runModal() == .alertFirstButtonReturn else { return }
        do {
            let bak = try HookInstaller.install()
            store.hooksInstalled = true
            info("Hooks instalados",
                 "Abra uma nova sessão do Claude Code para ela aparecer no notch."
                 + (bak.map { "\n\nBackup: \($0.path)" } ?? ""))
        } catch {
            info("Não foi possível instalar", error.localizedDescription + "\nNada foi alterado.")
        }
    }

    @objc private func uninstallHooks() {
        do {
            let bak = try HookInstaller.uninstall()
            store.hooksInstalled = false
            info("Hooks removidos", bak.map { "Backup: \($0.path)" } ?? "")
        } catch {
            info("Não foi possível remover", error.localizedDescription + "\nNada foi alterado.")
        }
    }

    private func info(_ title: String, _ text: String) {
        NSApp.activate()
        let a = NSAlert()
        a.messageText = title
        a.informativeText = text
        a.runModal()
    }
}
