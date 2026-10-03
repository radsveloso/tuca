import AppKit
import SwiftUI

let args = CommandLine.arguments
if let i = args.firstIndex(of: "--render"), i + 1 < args.count {
    MainActor.assumeIsolated { RenderMode.run(dir: args[i + 1]) }
    exit(0)
}

@MainActor
final class PlaygroundDelegate: NSObject, NSApplicationDelegate {
    let model = PlaygroundModel()
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 780),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = "Tuca · Character Playground"
        window.contentView = NSHostingView(rootView: PlaygroundRoot(model: model))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    let d = PlaygroundDelegate()
    app.delegate = d
    app.run()
}
