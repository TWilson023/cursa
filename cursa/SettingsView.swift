import SwiftUI

struct SettingsView: View {
    @Bindable var appState: AppState

    var body: some View {
        Form {
            Section("Global Hotkeys") {
                HotkeyRow(label: "Stop Playback", keyPath: \.stopHotkey)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 400, minHeight: 200)
        .padding()
    }
}

private struct HotkeyRow: View {
    let label: String
    let keyPath: ReferenceWritableKeyPath<HotkeyManager, HotkeyManager.HotkeyBinding>

    private let hotkeys = HotkeyManager.shared

    var body: some View {
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
