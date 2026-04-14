import CoreGraphics
import Foundation

struct RecordedPath: MousePath {
    let rawPoints: [MousePoint]
    let clicks: [ClickEvent]
    let pinnedIndices: Set<Int>
    let isLooping = false

    var duration: TimeInterval {
        rawPoints.last?.timestamp ?? 0
    }

    var points: [MousePoint] {
        rawPoints
    }

    func smoothed(level: Double) -> RecordedPath {
        guard level > 0, rawPoints.count > 2 else { return self }

        let windowSize = max(2, Int(level * 20))
        let halfWindow = windowSize / 2

        var smoothedPoints = rawPoints
        for i in 0..<rawPoints.count {
            if pinnedIndices.contains(i) { continue }

            let lo = max(0, i - halfWindow)
            let hi = min(rawPoints.count - 1, i + halfWindow)
            var sumX = 0.0
            var sumY = 0.0
            var count = 0.0
            for j in lo...hi {
                sumX += rawPoints[j].position.x
                sumY += rawPoints[j].position.y
                count += 1
            }
            smoothedPoints[i] = MousePoint(
                timestamp: rawPoints[i].timestamp,
                position: CGPoint(x: sumX / count, y: sumY / count)
            )
        }

        return RecordedPath(rawPoints: smoothedPoints, clicks: clicks, pinnedIndices: pinnedIndices)
    }
}
