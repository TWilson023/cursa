import AppKit
import SwiftUI

final class WelcomeWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var onClose: (() -> Void)?

    var isVisible: Bool { window?.isVisible ?? false }

    func show(appState: AppState, onClose: @escaping () -> Void) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        self.onClose = onClose

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 480),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Cursa"
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.delegate = self

        let hostingView = NSHostingView(rootView: WelcomeView(appState: appState) { [weak self] in
            self?.dismiss()
        })
        let fitting = hostingView.fittingSize
        hostingView.frame = NSRect(origin: .zero, size: fitting)
        window.setContentSize(fitting)
        window.contentView = hostingView
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }

    func dismiss() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
        onClose = nil
        window = nil
    }
}
