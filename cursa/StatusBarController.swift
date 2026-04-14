import AppKit
import Carbon.HIToolbox
import Observation
import SwiftUI

final class StatusBarController {
    static let shared = StatusBarController()

    private var statusItem: NSStatusItem?
    private var appState: AppState?
    private var settingsWindow: NSWindow?
    private let welcomeController = WelcomeWindowController()
    private let updateController = UpdateController()

    private enum Keys {
        static let hasSeenWelcome = "hasSeenWelcome"
    }

    private init() {}

    func setup(appState: AppState) {
        self.appState = appState

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = statusItem

        // Use button action instead of statusItem.menu so we can intercept clicks
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .leftMouseDown])
        }

        updateButton()
        rebuildMenu()
        startTracking()

        // Init accessibility + hotkeys. Check trust quietly — the welcome window
        // handles prompting the user, so we don't want the system alert here.
        appState.hasAccessibilityPermission = AccessibilityChecker.isTrusted()
        HotkeyManager.shared.start(appState: appState)

        // Listen for AX permission changes from System Settings instead of polling.
        // Distributed notification name `com.apple.accessibility.api` fires whenever
        // the Accessibility trust database changes.
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.accessibility.api"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // The trust check doesn't reflect the new state immediately; defer a tick.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                self?.refreshAccessibilityState()
            }
        }

        // Also re-check when the app becomes active, in case we missed a change.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshAccessibilityState()
        }

        showWelcomeIfNeeded()
    }

    private func refreshAccessibilityState() {
        guard let appState else { return }
        let trusted = AccessibilityChecker.isTrusted()
        if appState.hasAccessibilityPermission != trusted {
            appState.hasAccessibilityPermission = trusted
        }
        showWelcomeIfNeeded()
    }

    private func showWelcomeIfNeeded() {
        guard let appState else { return }
        let hasSeen = UserDefaults.standard.bool(forKey: Keys.hasSeenWelcome)
        guard !hasSeen || !appState.hasAccessibilityPermission else { return }
        guard !welcomeController.isVisible else { return }

        welcomeController.show(appState: appState) {
            if appState.hasAccessibilityPermission {
                UserDefaults.standard.set(true, forKey: Keys.hasSeenWelcome)
            }
        }
    }

    private func startTracking() {
        guard let appState else { return }
        withObservationTracking {
            _ = appState.activity
            _ = appState.hasAccessibilityPermission
            _ = appState.hasRecording
            _ = appState.playbackMode
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                self?.updateButton()
                self?.rebuildMenu()
                self?.startTracking()
            }
        }
    }

    private func updateButton() {
        guard let button = statusItem?.button, let appState else { return }

        if appState.isRecording {
            button.image = NSImage(systemSymbolName: "stop.fill", accessibilityDescription: "Stop Recording")
            let hotkey = HotkeyManager.shared.recordHotkey.displayString
            button.title = " \(hotkey)"
            button.imagePosition = .imageLeading
        } else {
            let icon = NSImage(named: "MenuBarIcon")
            icon?.isTemplate = true
            button.image = icon
            button.title = ""
            button.imagePosition = .imageOnly
        }
    }

    private func rebuildMenu() {
        guard let appState else { return }
        let menu = NSMenu()
        menu.autoenablesItems = false
        let enabled = appState.hasAccessibilityPermission

        if !enabled {
            let permItem = NSMenuItem(title: "Accessibility Permission Required…", action: #selector(openWelcome), keyEquivalent: "")
            permItem.target = self
            menu.addItem(permItem)
            menu.addItem(.separator())
        }

        // Record
        let recordTitle: String
        let recordHotkey = HotkeyManager.shared.recordHotkey
        if appState.isRecording {
            recordTitle = "Stop Recording"
        } else {
            recordTitle = "Record"
        }
        let recordItem = NSMenuItem(title: recordTitle, action: #selector(toggleRecord), keyEquivalent: "")
        recordItem.target = self
        recordItem.isEnabled = enabled && !appState.isPlaying
        // Show hotkey as the shortcut display
        if let (key, mods) = keyEquivalent(for: recordHotkey) {
            recordItem.keyEquivalent = key
            recordItem.keyEquivalentModifierMask = mods
        }
        menu.addItem(recordItem)

        // Play
        let playTitle = appState.isPlaying ? "Stop Playback" : "Play Recording"
        let playItem = NSMenuItem(title: playTitle, action: #selector(togglePlay), keyEquivalent: "")
        playItem.target = self
        playItem.isEnabled = enabled && !appState.isRecording && (appState.isPlaying || appState.hasRecording)
        let playHotkey = HotkeyManager.shared.playHotkey
        if let (key, mods) = keyEquivalent(for: playHotkey) {
            playItem.keyEquivalent = key
            playItem.keyEquivalentModifierMask = mods
        }
        menu.addItem(playItem)

        // Recording loop mode submenu
        let loopMenu = NSMenu()
        for mode in PlaybackMode.allCases {
            let item = NSMenuItem(title: mode.rawValue, action: #selector(setLoopMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            item.state = appState.playbackMode == mode ? .on : .off
            loopMenu.addItem(item)
        }
        let loopItem = NSMenuItem(title: "Recording Loop Mode", action: nil, keyEquivalent: "")
        loopItem.submenu = loopMenu
        menu.addItem(loopItem)

        menu.addItem(.separator())

        // Presets
        let circleItem = NSMenuItem(title: "Circle", action: #selector(presetCircle), keyEquivalent: "")
        circleItem.target = self
        circleItem.isEnabled = enabled && appState.activity == .idle
        menu.addItem(circleItem)

        let fig8Item = NSMenuItem(title: "Figure-8", action: #selector(presetFigure8), keyEquivalent: "")
        fig8Item.target = self
        fig8Item.isEnabled = enabled && appState.activity == .idle
        menu.addItem(fig8Item)

        let lineItem = NSMenuItem(title: "Line", action: #selector(presetLine), keyEquivalent: "")
        lineItem.target = self
        lineItem.isEnabled = enabled && appState.activity == .idle
        menu.addItem(lineItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let updateItem = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        updateItem.target = self
        updateItem.isEnabled = updateController.canCheckForUpdates
        menu.addItem(updateItem)

        let quitItem = NSMenuItem(title: "Quit Cursa", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        currentMenu = menu
    }

    private var currentMenu: NSMenu?

    @objc private func statusItemClicked() {
        // If recording, stop it before showing the menu
        if let appState, appState.isRecording {
            stopRecording()
            rebuildMenu()
        }

        // Show the menu programmatically
        guard let button = statusItem?.button, let menu = currentMenu else { return }
        statusItem?.menu = menu
        button.performClick(nil)
        // Clear menu so future clicks go through our action handler again
        DispatchQueue.main.async { [weak self] in
            self?.statusItem?.menu = nil
        }
    }

    // MARK: - Actions

    @objc private func openWelcome() {
        showWelcomeIfNeeded()
    }

    private var countdownTimer: Timer?

    @objc private func toggleRecord() {
        guard let appState else { return }
        if appState.isRecording {
            stopRecording()
        } else if appState.activity == .idle {
            startCountdown()
        }
    }

    func stopRecording() {
        guard let appState else { return }
        let recording = MouseRecorder.shared.stopRecording()
        appState.activity = .idle
        if let recording {
            appState.hasRecording = true
            MousePlayer.shared.setRecording(recording)
        }
        updateButton()
    }

    func startCountdown() {
        guard let appState, appState.activity == .idle else { return }
        guard let button = statusItem?.button else { return }

        // Cancel any existing countdown
        countdownTimer?.invalidate()

        var remaining = 3
        button.image = nil
        button.title = "\(remaining)"
        button.imagePosition = .noImage

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            remaining -= 1
            if remaining > 0 {
                button.title = "\(remaining)"
            } else {
                timer.invalidate()
                self?.countdownTimer = nil
                MouseRecorder.shared.startRecording(appState: appState)
                self?.updateButton()
                self?.rebuildMenu()
            }
        }
    }

    func cancelCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        updateButton()
    }

    @objc private func togglePlay() {
        guard let appState else { return }
        if appState.isPlaying {
            MousePlayer.shared.stop(appState: appState)
        } else {
            MousePlayer.shared.playRecording(appState: appState)
        }
    }

    @objc private func presetCircle() {
        guard let appState else { return }
        OverlayCoordinator.shared.beginConfiguration(for: .circle, appState: appState)
    }

    @objc private func presetFigure8() {
        guard let appState else { return }
        OverlayCoordinator.shared.beginConfiguration(for: .figure8, appState: appState)
    }

    @objc private func presetLine() {
        guard let appState else { return }
        OverlayCoordinator.shared.beginConfiguration(for: .line, appState: appState)
    }

    @objc private func setLoopMode(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let mode = PlaybackMode(rawValue: rawValue) else { return }
        appState?.playbackMode = mode
    }

    @objc private func openSettings() {
        guard let appState else { return }

        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Cursa Settings"
        window.contentView = NSHostingView(rootView: SettingsView(appState: appState))
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    @objc private func checkForUpdates() {
        updateController.checkForUpdates(nil)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Helpers

    private func keyEquivalent(for binding: HotkeyManager.HotkeyBinding) -> (String, NSEvent.ModifierFlags)? {
        let key = keyCharForKeyCode(binding.keyCode)
        guard !key.isEmpty else { return nil }
        return (key, binding.modifiers)
    }
}

private func keyCharForKeyCode(_ keyCode: UInt16) -> String {
    // Convert key code to lowercase character for NSMenuItem.keyEquivalent
    // Uses TISCopyCurrentKeyboardInputSource for accurate mapping
    if let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
       let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) {
        let data = unsafeBitCast(layoutData, to: CFData.self) as Data
        return data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> String in
            let layoutPtr = ptr.bindMemory(to: UCKeyboardLayout.self).baseAddress!
            var deadKeyState: UInt32 = 0
            var chars = [UniChar](repeating: 0, count: 4)
            var length: Int = 0
            let status = UCKeyTranslate(
                layoutPtr,
                keyCode,
                UInt16(kUCKeyActionDisplay),
                0, // no modifiers
                UInt32(LMGetKbdType()),
                UInt32(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                4,
                &length,
                &chars
            )
            if status == noErr && length > 0 {
                return String(utf16CodeUnits: chars, count: length).lowercased()
            }
            return ""
        }
    }

    // Fallback: hardcoded mapping
    let mapping: [UInt16: String] = [
        0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x",
        8: "c", 9: "v", 11: "b", 12: "q", 13: "w", 14: "e", 15: "r",
        16: "y", 17: "t", 31: "o", 32: "u", 34: "i", 35: "p", 37: "l",
        38: "j", 40: "k", 45: "n", 46: "m",
    ]
    return mapping[keyCode] ?? ""
}
