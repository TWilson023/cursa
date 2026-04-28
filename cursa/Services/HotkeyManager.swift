import AppKit
import Carbon.HIToolbox

@Observable
final class HotkeyManager {
    @ObservationIgnored static let shared = HotkeyManager()

    @ObservationIgnored private var monitors: [Any] = []
    @ObservationIgnored private weak var appState: AppState?

    struct HotkeyBinding: Equatable {
        var keyCode: UInt16
        var modifiers: NSEvent.ModifierFlags

        var displayString: String {
            var parts: [String] = []
            if modifiers.contains(.control) { parts.append("⌃") }
            if modifiers.contains(.option) { parts.append("⌥") }
            if modifiers.contains(.shift) { parts.append("⇧") }
            if modifiers.contains(.command) { parts.append("⌘") }
            parts.append(keyStringForKeyCode(keyCode))
            return parts.joined()
        }
    }

    // Default: ⌃⌥X
    var stopHotkey = HotkeyBinding(keyCode: UInt16(kVK_ANSI_X), modifiers: [.control, .option])

    private init() {
        loadFromDefaults()
    }

    func start(appState: AppState) {
        self.appState = appState
        registerMonitors()
    }

    func reregister() {
        unregisterMonitors()
        registerMonitors()
    }

    private func registerMonitors() {
        let globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
        if let globalMonitor {
            monitors.append(globalMonitor)
        }

        let localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }
        if let localMonitor {
            monitors.append(localMonitor)
        }
    }

    private func unregisterMonitors() {
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
        monitors.removeAll()
    }

    private func handleKeyEvent(_ event: NSEvent) {
        guard let appState else { return }
        let mods = event.modifierFlags.intersection([.control, .option, .shift, .command])

        if event.keyCode == stopHotkey.keyCode && mods == stopHotkey.modifiers {
            if appState.isPlaying {
                MousePlayer.shared.stop(appState: appState)
            }
        }
    }

    func saveToDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(Int(stopHotkey.keyCode), forKey: "hotkey_stop_keyCode")
        defaults.set(Int(stopHotkey.modifiers.rawValue), forKey: "hotkey_stop_modifiers")
    }

    private func loadFromDefaults() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "hotkey_stop_keyCode") != nil {
            stopHotkey.keyCode = UInt16(defaults.integer(forKey: "hotkey_stop_keyCode"))
            stopHotkey.modifiers = NSEvent.ModifierFlags(rawValue: UInt(defaults.integer(forKey: "hotkey_stop_modifiers")))
        }
    }
}

private func keyStringForKeyCode(_ keyCode: UInt16) -> String {
    let mapping: [UInt16: String] = [
        UInt16(kVK_ANSI_A): "A", UInt16(kVK_ANSI_B): "B", UInt16(kVK_ANSI_C): "C",
        UInt16(kVK_ANSI_D): "D", UInt16(kVK_ANSI_E): "E", UInt16(kVK_ANSI_F): "F",
        UInt16(kVK_ANSI_G): "G", UInt16(kVK_ANSI_H): "H", UInt16(kVK_ANSI_I): "I",
        UInt16(kVK_ANSI_J): "J", UInt16(kVK_ANSI_K): "K", UInt16(kVK_ANSI_L): "L",
        UInt16(kVK_ANSI_M): "M", UInt16(kVK_ANSI_N): "N", UInt16(kVK_ANSI_O): "O",
        UInt16(kVK_ANSI_P): "P", UInt16(kVK_ANSI_Q): "Q", UInt16(kVK_ANSI_R): "R",
        UInt16(kVK_ANSI_S): "S", UInt16(kVK_ANSI_T): "T", UInt16(kVK_ANSI_U): "U",
        UInt16(kVK_ANSI_V): "V", UInt16(kVK_ANSI_W): "W", UInt16(kVK_ANSI_X): "X",
        UInt16(kVK_ANSI_Y): "Y", UInt16(kVK_ANSI_Z): "Z",
        UInt16(kVK_Space): "Space", UInt16(kVK_Escape): "Esc",
        UInt16(kVK_F1): "F1", UInt16(kVK_F2): "F2", UInt16(kVK_F3): "F3",
    ]
    return mapping[keyCode] ?? "Key\(keyCode)"
}
