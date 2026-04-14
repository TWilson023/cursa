import SwiftUI

struct SettingsView: View {
    @Bindable var appState: AppState

    var body: some View {
        TabView {
            Tab("Hotkeys", systemImage: "keyboard") {
                HotkeysTab()
            }
            Tab("Playback", systemImage: "play.circle") {
                playbackTab
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        .padding()
    }

    // MARK: - Playback Tab

    private var playbackTab: some View {
        Form {
            Section("Smoothing") {
                HStack {
                    Text("Level")
                    Slider(value: $appState.smoothingLevel, in: 0...1, step: 0.05)
                    Text("\(Int(appState.smoothingLevel * 100))%")
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }
                Text("Reduces jitter in recorded paths. Click positions are always preserved.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Loop Mode") {
                Picker("Mode", selection: $appState.playbackMode) {
                    ForEach(PlaybackMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Hotkeys Tab

private struct HotkeysTab: View {
    private let hotkeys = HotkeyManager.shared

    var body: some View {
        Form {
            Section("Global Hotkeys") {
                row("Record Start/Stop", keyPath: \.recordHotkey)
                row("Play Start/Stop", keyPath: \.playHotkey)
                row("Stop All", keyPath: \.stopHotkey)
            }
        }
        .formStyle(.grouped)
    }

    private func row(_ label: String, keyPath: ReferenceWritableKeyPath<HotkeyManager, HotkeyManager.HotkeyBinding>) -> some View {
        HStack {
            Text(label)
            Spacer()
            HotkeyField(value: hotkeys[keyPath: keyPath]) { newBinding in
                hotkeys[keyPath: keyPath] = newBinding
                hotkeys.saveToDefaults()
                hotkeys.reregister()
            }
        }
    }
}

// MARK: - Hotkey Field

struct HotkeyField: View {
    let value: HotkeyManager.HotkeyBinding
    let onChange: (HotkeyManager.HotkeyBinding) -> Void

    @State private var isRecording = false

    var body: some View {
        Button(isRecording ? "Press keys…" : value.displayString) {
            isRecording = true
        }
        .buttonStyle(.bordered)
        .frame(minWidth: 100)
        .background {
            if isRecording {
                HotkeyRecorderView { keyCode, modifiers in
                    onChange(HotkeyManager.HotkeyBinding(keyCode: keyCode, modifiers: modifiers))
                    isRecording = false
                }
                .frame(width: 0, height: 0)
            }
        }
    }
}

struct HotkeyRecorderView: NSViewRepresentable {
    let onCapture: (UInt16, NSEvent.ModifierFlags) -> Void

    func makeNSView(context: Context) -> HotkeyCapture {
        let view = HotkeyCapture(onCapture: onCapture)
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: HotkeyCapture, context: Context) {}

    class HotkeyCapture: NSView {
        let onCapture: (UInt16, NSEvent.ModifierFlags) -> Void

        init(onCapture: @escaping (UInt16, NSEvent.ModifierFlags) -> Void) {
            self.onCapture = onCapture
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError() }

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            let mods = event.modifierFlags.intersection([.control, .option, .shift, .command])
            guard !mods.isEmpty else { return }
            onCapture(event.keyCode, mods)
        }
    }
}
