import AppKit
import SwiftUI

final class OverlayWindowController {
    private var window: NSWindow?
    private let config: PresetConfiguration
    private let onCancel: () -> Void

    init(config: PresetConfiguration, onCancel: @escaping () -> Void) {
        self.config = config
        self.onCancel = onCancel
    }

    func show() {
        guard let screen = NSScreen.main else { return }

        let window = OverlayWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .init(rawValue: Int(CGWindowLevelForKey(.maximumWindow)) - 1)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.acceptsMouseMovedEvents = true
        let onCancel = self.onCancel
        let hostingView = NSHostingView(
            rootView: OverlayView(config: config, onCancel: onCancel)
                .frame(width: screen.frame.width, height: screen.frame.height)
        )
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }

    func dismiss() {
        window?.orderOut(nil)
        window = nil
    }
}

private class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    // Accept the very first click without requiring a separate click to focus
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            makeKey()
        }
        super.sendEvent(event)
    }
}
