import AppKit
import Sparkle

/// Thin wrapper around Sparkle's `SPUStandardUpdaterController` so the rest of
/// the app doesn't need to know about Sparkle types directly. The controller
/// is held by `StatusBarController` for the lifetime of the app.
final class UpdateController {
    private let updaterController: SPUStandardUpdaterController

    init() {
        // `startingUpdater: true` kicks off the background update schedule as
        // configured in Info.plist (SUEnableAutomaticChecks, SUFeedURL, etc.).
        // We don't need a delegate for the v1 flow — Sparkle's default UI and
        // scheduling are fine.
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    /// Manually triggers the "Check for Updates…" dialog. Wired to the menu item.
    @objc func checkForUpdates(_ sender: Any?) {
        updaterController.checkForUpdates(sender)
    }

    /// Exposed so menu items can validate against Sparkle's internal state
    /// (e.g. disable the item while an update check is already running).
    var canCheckForUpdates: Bool {
        updaterController.updater.canCheckForUpdates
    }
}
