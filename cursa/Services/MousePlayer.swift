import CoreGraphics
import Foundation

enum PresetType {
    case circle, figure8, line
}

final class MousePlayer {
    static let shared = MousePlayer()

    private var timer: DispatchSourceTimer?
    private var playbackStart: TimeInterval = 0
    private weak var currentAppState: AppState?

    private var cachedPoints: [MousePoint] = []
    private var cachedDuration: TimeInterval = 0

    private var lastPostedPosition: CGPoint?
    private var tickCount: Int = 0
    private var deviationStreak: Int = 0
    private let autoCancelThreshold: Double = 8.0
    private let autoCancelGraceTicks: Int = 15
    private let autoCancelStreakRequired: Int = 3

    private init() {}

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

        let firstPoint = path.points.first?.position ?? startPoint
        if appState.startingClick {
            postStartingClick(at: firstPoint)
        } else {
            moveMouse(to: firstPoint)
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
        cachedDuration = path.duration

        guard !cachedPoints.isEmpty, cachedDuration > 0 else { return }

        currentAppState = appState
        playbackStart = ProcessInfo.processInfo.systemUptime
        lastPostedPosition = nil
        tickCount = 0
        deviationStreak = 0
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

        if tickCount > autoCancelGraceTicks, let expected = lastPostedPosition {
            let actual = CGEvent(source: nil)?.location ?? expected
            let dx = actual.x - expected.x
            let dy = actual.y - expected.y
            if sqrt(dx * dx + dy * dy) > autoCancelThreshold {
                deviationStreak += 1
                if deviationStreak >= autoCancelStreakRequired {
                    stop(appState: appState)
                    return
                }
            } else {
                deviationStreak = 0
            }
        }

        let elapsed = ProcessInfo.processInfo.systemUptime - playbackStart
        let t = elapsed.truncatingRemainder(dividingBy: cachedDuration)
        let position = interpolatePosition(time: t)
        moveMouse(to: position)
        lastPostedPosition = position
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

    private func postStartingClick(at point: CGPoint) {
        let source = CGEventSource(stateID: .hidSystemState)

        // Move cursor to the click location first; some apps ignore clicks that
        // arrive without a preceding hover at that position.
        if let move = CGEvent(
            mouseEventSource: source,
            mouseType: .mouseMoved,
            mouseCursorPosition: point,
            mouseButton: .left
        ) {
            move.post(tap: .cghidEventTap)
        }
        Thread.sleep(forTimeInterval: 0.02)

        for type in [CGEventType.leftMouseDown, .leftMouseUp] {
            guard let event = CGEvent(
                mouseEventSource: source,
                mouseType: type,
                mouseCursorPosition: point,
                mouseButton: .left
            ) else { continue }
            event.setIntegerValueField(.mouseEventClickState, value: 1)
            event.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: 0.02)
        }
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
        cachedPoints = []
        lastPostedPosition = nil
    }
}
