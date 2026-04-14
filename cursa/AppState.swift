import SwiftUI

enum PlaybackMode: String, CaseIterable {
    case once = "Once"
    case pingPong = "Ping-Pong"
    case loop = "Repeat"
}

enum AppActivity: Equatable {
    case idle
    case recording
    case playing
    case configuring
}

@Observable
final class AppState {
    var activity: AppActivity = .idle

    var playbackMode: PlaybackMode {
        didSet { UserDefaults.standard.set(playbackMode.rawValue, forKey: Keys.playbackMode) }
    }

    var smoothingLevel: Double {
        didSet { UserDefaults.standard.set(smoothingLevel, forKey: Keys.smoothingLevel) }
    }

    var startingClick: Bool {
        didSet { UserDefaults.standard.set(startingClick, forKey: Keys.startingClick) }
    }

    var isRecording: Bool { activity == .recording }
    var isPlaying: Bool { activity == .playing }

    var hasAccessibilityPermission: Bool = false
    var hasRecording: Bool = false

    init() {
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: Keys.playbackMode),
           let mode = PlaybackMode(rawValue: raw) {
            playbackMode = mode
        } else {
            playbackMode = .loop
        }
        smoothingLevel = (defaults.object(forKey: Keys.smoothingLevel) as? Double) ?? 0.0
        startingClick = (defaults.object(forKey: Keys.startingClick) as? Bool) ?? true
    }

    private enum Keys {
        static let playbackMode = "playbackMode"
        static let smoothingLevel = "smoothingLevel"
        static let startingClick = "startingClick"
    }
}
