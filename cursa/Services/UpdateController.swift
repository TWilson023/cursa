import AppKit
import Sparkle

/// Thin wrapper around Sparkle's `SPUStandardUpdaterController` so the rest of
/// the app doesn't need to know about Sparkle types directly. The controller
/// is held by `StatusBarController` for the lifetime of the app.
final class UpdateController: NSObject, SPUStandardUserDriverDelegate {
    private var updaterController: SPUStandardUpdaterController!

    override init() {
        super.init()
        // `startingUpdater: true` kicks off the background update schedule as
        // configured in Info.plist (SUEnableAutomaticChecks, SUFeedURL, etc.).
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: self
        )
    }

    // Cursa is LSUIElement (menu bar app); Sparkle logs a warning if a
    // background app schedules update checks without declaring gentle-reminder
    // support. We don't need any custom UI — declaring support is enough to
    // silence the warning and lets Sparkle handle reminders appropriately.
    var supportsGentleScheduledUpdateReminders: Bool { true }

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
