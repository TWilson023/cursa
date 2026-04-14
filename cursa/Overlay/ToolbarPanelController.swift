import AppKit
import SwiftUI

final class ToolbarPanelController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private let config: PresetConfiguration
    private let appState: AppState
    private let onStart: () -> Void
    private let onCancel: () -> Void

    init(config: PresetConfiguration, appState: AppState, onStart: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.config = config
        self.appState = appState
        self.onStart = onStart
        self.onCancel = onCancel
        super.init()
    }

    func windowWillClose(_ notification: Notification) {
        onCancel()
    }

    func show() {
        guard let screen = NSScreen.main else { return }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 200),
            styleMask: [.titled, .closable, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "\(presetName) Preset"
        panel.isFloatingPanel = true
        panel.level = .init(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        panel.becomesKeyOnlyIfNeeded = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.delegate = self

        let hostingView = NSHostingView(
            rootView: ToolbarView(config: config, appState: appState, onStart: onStart, onCancel: onCancel)
        )
        let fittingSize = hostingView.fittingSize
        hostingView.frame = NSRect(origin: .zero, size: fittingSize)
        panel.contentView = hostingView
        panel.setContentSize(fittingSize)

        // Position top-right of screen
        let screenFrame = screen.visibleFrame
        let panelFrame = panel.frame
        let x = screenFrame.maxX - panelFrame.width - 20
        let y = screenFrame.maxY - panelFrame.height - 20
        panel.setFrameOrigin(NSPoint(x: x, y: y))

        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }

    private var presetName: String {
        switch config.presetType {
        case .circle: "Circle"
        case .figure8: "Figure-8"
        case .line: "Line"
        }
    }
}
