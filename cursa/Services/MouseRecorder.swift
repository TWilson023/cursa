import CoreGraphics
import Foundation

final class MouseRecorder {
    static let shared = MouseRecorder()

    nonisolated(unsafe) private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    nonisolated(unsafe) private var recordedPoints: [MousePoint] = []
    nonisolated(unsafe) private var recordedClicks: [ClickEvent] = []
    nonisolated(unsafe) private var pinnedIndices: Set<Int> = []
    nonisolated(unsafe) private var startTime: TimeInterval = 0

    private init() {}

    func startRecording(appState: AppState) {
        guard appState.activity == .idle else { return }

        recordedPoints = []
        recordedClicks = []
        pinnedIndices = []
        startTime = ProcessInfo.processInfo.systemUptime

        let eventMask: CGEventMask = (
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.rightMouseDragged.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.rightMouseUp.rawValue) |
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.otherMouseUp.rawValue)
        )

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passRetained(event) }
            let recorder = Unmanaged<MouseRecorder>.fromOpaque(userInfo).takeUnretainedValue()

            // The system disables long-running or misbehaving taps. Re-enable so
            // recording keeps working instead of silently dying mid-session.
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = recorder.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return Unmanaged.passRetained(event)
            }

            recorder.handleEvent(type: type, event: event)
            return Unmanaged.passRetained(event)
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: selfPtr
        ) else {
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        appState.activity = .recording
    }

    func stopRecording() -> RecordedPath? {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            }
        }
        eventTap = nil
        runLoopSource = nil

        guard !recordedPoints.isEmpty else { return nil }

        // Strip any clicks in the last 100ms — these are likely the click
        // that stopped recording (menu bar icon or other UI interaction)
        let cutoff = (recordedPoints.last?.timestamp ?? 0) - 0.1
        let trimmedClicks = recordedClicks.filter { $0.timestamp < cutoff }

        return RecordedPath(
            rawPoints: recordedPoints,
            clicks: trimmedClicks,
            pinnedIndices: pinnedIndices
        )
    }

    nonisolated private func handleEvent(type: CGEventType, event: CGEvent) {
        let now = ProcessInfo.processInfo.systemUptime
        let timestamp = now - startTime
        let position = event.location

        switch type {
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged:
            recordedPoints.append(MousePoint(timestamp: timestamp, position: position))

        case .leftMouseDown:
            appendClick(.leftDown, timestamp: timestamp, position: position)
        case .leftMouseUp:
            recordedClicks.append(ClickEvent(timestamp: timestamp, position: position, type: .leftUp))
        case .rightMouseDown:
            appendClick(.rightDown, timestamp: timestamp, position: position)
        case .rightMouseUp:
            recordedClicks.append(ClickEvent(timestamp: timestamp, position: position, type: .rightUp))
        case .otherMouseDown:
            appendClick(.otherDown, timestamp: timestamp, position: position)
        case .otherMouseUp:
            recordedClicks.append(ClickEvent(timestamp: timestamp, position: position, type: .otherUp))

        default:
            break
        }
    }

    nonisolated private func appendClick(_ type: ClickType, timestamp: TimeInterval, position: CGPoint) {
        recordedClicks.append(ClickEvent(timestamp: timestamp, position: position, type: type))
        // Pin the point we're about to append so smoothing won't shift where the click lands.
        pinnedIndices.insert(recordedPoints.count)
        recordedPoints.append(MousePoint(timestamp: timestamp, position: position))
    }
}
