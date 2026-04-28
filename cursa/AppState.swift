import SwiftUI

enum AppActivity: Equatable {
    case idle
    case playing
    case configuring
}

@Observable
final class AppState {
    var activity: AppActivity = .idle

    var startingClick: Bool {
        didSet { UserDefaults.standard.set(startingClick, forKey: Keys.startingClick) }
    }

    var isPlaying: Bool { activity == .playing }

    var hasAccessibilityPermission: Bool = false

    init() {
        let defaults = UserDefaults.standard
        startingClick = (defaults.object(forKey: Keys.startingClick) as? Bool) ?? true
    }

    private enum Keys {
        static let startingClick = "startingClick"
    }
}
