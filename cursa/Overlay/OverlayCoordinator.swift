import Foundation

final class OverlayCoordinator {
    static let shared = OverlayCoordinator()

    private var overlayController: OverlayWindowController?
    private var toolbarController: ToolbarPanelController?
    private(set) var config: PresetConfiguration?

    private init() {}

    func beginConfiguration(for preset: PresetType, appState: AppState) {
        guard appState.activity == .idle else { return }

        let config = PresetConfiguration()
        config.reset(for: preset)
        self.config = config

        appState.activity = .configuring

        // Small delay so the menu bar dropdown finishes dismissing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self else { return }

            self.overlayController = OverlayWindowController(config: config) { [weak self] in
                self?.cancelConfiguration(appState: appState)
            }

            self.toolbarController = ToolbarPanelController(
                config: config,
                appState: appState,
                onStart: { [weak self] in
                    self?.startPlayback(appState: appState)
                },
                onCancel: { [weak self] in
                    self?.cancelConfiguration(appState: appState)
                }
            )

            self.overlayController?.show()
            self.toolbarController?.show()
        }
    }

    private func startPlayback(appState: AppState) {
        guard let config else { return }
        dismiss()
        appState.activity = .idle
        // Defer playback so the overlay/toolbar windows are fully off-screen
        // and Cursa has yielded frontmost status before the starting click
        // fires. Without this, the synthetic click races the dismiss and the
        // target app gets activated only momentarily before Cursa's still-
        // tearing-down panel reclaims focus.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            MousePlayer.shared.playConfiguredPreset(config: config, appState: appState)
        }
    }

    func cancelConfiguration(appState: AppState) {
        dismiss()
        appState.activity = .idle
    }

    private func dismiss() {
        overlayController?.dismiss()
        toolbarController?.dismiss()
        overlayController = nil
        toolbarController = nil
        config = nil
    }
}
