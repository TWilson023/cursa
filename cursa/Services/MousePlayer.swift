import CoreGraphics
import Foundation

enum PresetType {
    case circle, figure8, line
}

final class MousePlayer {
    static let shared = MousePlayer()

    private var timer: DispatchSourceTimer?
    private var playbackStart: TimeInterval = 0
    private var clickIndex: Int = 0
    private weak var currentAppState: AppState?

    // Snapshot of the current path taken at startPlayback time. Computed properties
    // on preset paths re-run sin/cos on every access, so we cache once per run.
    private var cachedPoints: [MousePoint] = []
    private var cachedClicks: [ClickEvent] = []
    private var cachedDuration: TimeInterval = 0
    private var cachedIsLooping: Bool = false

    // Auto-cancel: detect physical mouse movement
    private var lastPostedPosition: CGPoint?
    private var tickCount: Int = 0
    private let autoCancelThreshold: Double = 5.0

    private var lastRecording: RecordedPath?

    private init() {}

    var hasRecording: Bool { lastRecording != nil }

    func setRecording(_ recording: RecordedPath) {
        lastRecording = recording
    }

    func playRecording(appState: AppState) {
        guard let recording = lastRecording else { return }

        let path: RecordedPath = appState.smoothingLevel > 0
            ? recording.smoothed(level: appState.smoothingLevel)
            : recording

        startPlayback(path: path, appState: appState)
    }

    func playConfiguredPreset(config: PresetConfiguration, appState: AppState) {
        let path: any MousePath
        let startPoint: CGPoint
        switch config.presetType {
        case .circle:
            path = CirclePath(
                center: config.center,
                radius: config.radius,
                duration: config.speed
            )
            startPoint = CGPoint(x: config.center.x + config.radius, y: config.center.y)
        case .figure8:
            path = Figure8Path(
                center: config.center,
                size: config.size,
                duration: config.speed
            )
            startPoint = config.center
        case .line:
            path = LinePath(
                start: config.startPoint,
                end: config.endPoint,
                duration: config.speed
            )
            startPoint = config.startPoint
        }

        if appState.startingClick {
            postStartingClick(at: path.points.first?.position ?? startPoint)
        }

        startPlayback(path: path, appState: appState)
    }

    func stop(appState: AppState) {
        stopTimer()
        appState.activity = .idle
    }

    private func startPlayback(path: any MousePath, appState: AppState) {
        guard appState.activity == .idle else { return }

        cachedPoints = path.points
        cachedClicks = path.clicks
        cachedDuration = path.duration
        cachedIsLooping = path.isLooping

        guard !cachedPoints.isEmpty, cachedDuration > 0 else { return }

        currentAppState = appState
        playbackStart = ProcessInfo.processInfo.systemUptime
        clickIndex = 0
        lastPostedPosition = nil
        tickCount = 0
        appState.activity = .playing

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(16))
        timer.setEventHandler { [weak self] in
            self?.tick()
        }
        self.timer = timer
        timer.resume()
    }

    private func tick() {
        guard let appState = currentAppState else {
            stopTimer()
            return
        }

        tickCount += 1

        // Auto-cancel: check if user physically moved the mouse
        if tickCount > 3, let expected = lastPostedPosition {
            let actual = CGEvent(source: nil)?.location ?? expected
            let dx = actual.x - expected.x
            let dy = actual.y - expected.y
            if sqrt(dx * dx + dy * dy) > autoCancelThreshold {
                stop(appState: appState)
                return
            }
        }

        let elapsed = ProcessInfo.processInfo.systemUptime - playbackStart
        let t = currentTime(elapsed: elapsed, mode: appState.playbackMode)
        guard let t else {
            stop(appState: appState)
            return
        }

        let position = positionAt(time: t, mode: appState.playbackMode)
        moveMouse(to: position)
        lastPostedPosition = position

        postClicksUpTo(time: t)
    }

    /// Returns the path-local time for the given elapsed playback time, or `nil` if
    /// playback should stop (only in `.once` mode when the recording has finished).
    private func currentTime(elapsed: TimeInterval, mode: PlaybackMode) -> Double? {
        if cachedIsLooping {
            return elapsed.truncatingRemainder(dividingBy: cachedDuration)
        }
        switch mode {
        case .once:
            return elapsed >= cachedDuration ? nil : elapsed
        case .pingPong:
            let cycle = cachedDuration * 2
            let cyclePos = elapsed.truncatingRemainder(dividingBy: cycle)
            return cyclePos <= cachedDuration ? cyclePos : cachedDuration - (cyclePos - cachedDuration)
        case .loop:
            return elapsed.truncatingRemainder(dividingBy: cachedDuration)
        }
    }

    /// Looks up the interpolated position on the cached path, blending the seam
    /// in `.loop` mode so that a recording's end→start jump isn't a hard jerk.
    private func positionAt(time t: Double, mode: PlaybackMode) -> CGPoint {
        let interpolated = interpolatePosition(time: t)

        guard !cachedIsLooping, mode == .loop else { return interpolated }

        let transitionDuration = min(0.3, cachedDuration * 0.1)

        if t < transitionDuration, let last = cachedPoints.last {
            let blend = t / transitionDuration
            return lerp(from: last.position, to: interpolated, blend: blend)
        }
        if t > cachedDuration - transitionDuration, let first = cachedPoints.first {
            let blend = (t - (cachedDuration - transitionDuration)) / transitionDuration
            return lerp(from: interpolated, to: first.position, blend: blend)
        }
        return interpolated
    }

    private func lerp(from: CGPoint, to: CGPoint, blend: Double) -> CGPoint {
        CGPoint(
            x: from.x + (to.x - from.x) * blend,
            y: from.y + (to.y - from.y) * blend
        )
    }

    private func interpolatePosition(time: Double) -> CGPoint {
        let points = cachedPoints
        guard points.count > 1 else { return points.first?.position ?? .zero }

        if time <= points.first!.timestamp { return points.first!.position }
        if time >= points.last!.timestamp { return points.last!.position }

        var lo = 0
        var hi = points.count - 1
        while lo < hi - 1 {
            let mid = (lo + hi) / 2
            if points[mid].timestamp <= time {
                lo = mid
            } else {
                hi = mid
            }
        }

        let p0 = points[lo]
        let p1 = points[hi]
        let segDuration = p1.timestamp - p0.timestamp
        guard segDuration > 0 else { return p0.position }

        let frac = (time - p0.timestamp) / segDuration
        return lerp(from: p0.position, to: p1.position, blend: frac)
    }

    private func moveMouse(to point: CGPoint) {
        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: point,
            mouseButton: .left
        ) else { return }
        event.post(tap: .cghidEventTap)
    }

    private func postClicksUpTo(time: Double) {
        while clickIndex < cachedClicks.count && cachedClicks[clickIndex].timestamp <= time {
            postClick(cachedClicks[clickIndex])
            clickIndex += 1
        }
    }

    private func postStartingClick(at point: CGPoint) {
        let source = CGEventSource(stateID: .hidSystemState)
        for type in [CGEventType.leftMouseDown, .leftMouseUp] {
            guard let event = CGEvent(
                mouseEventSource: source,
                mouseType: type,
                mouseCursorPosition: point,
                mouseButton: .left
            ) else { continue }
            event.post(tap: .cghidEventTap)
        }
    }

    private func postClick(_ click: ClickEvent) {
        let (eventType, button): (CGEventType, CGMouseButton) = switch click.type {
        case .leftDown: (.leftMouseDown, .left)
        case .leftUp: (.leftMouseUp, .left)
        case .rightDown: (.rightMouseDown, .right)
        case .rightUp: (.rightMouseUp, .right)
        case .otherDown: (.otherMouseDown, .center)
        case .otherUp: (.otherMouseUp, .center)
        }

        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: eventType,
            mouseCursorPosition: click.position,
            mouseButton: button
        ) else { return }
        event.post(tap: .cghidEventTap)
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
        cachedPoints = []
        cachedClicks = []
        lastPostedPosition = nil
    }
}
