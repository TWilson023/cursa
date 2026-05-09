import CoreGraphics
import Foundation

struct LinePath: MousePath {
    let start: CGPoint
    let end: CGPoint
    let duration: Double
    let isLooping = true

    var points: [MousePoint] {
        let stepCount = max(Int(duration * 60), 60)
        return (0...stepCount).map { i in
            let t = Double(i) / Double(stepCount)
            // Cosine ease: goes start → end → start over the full duration,
            // with smooth turnarounds at the endpoints and seamless looping.
            let progress = (1 - cos(2 * .pi * t)) / 2
            let x = start.x + (end.x - start.x) * progress
            let y = start.y + (end.y - start.y) * progress
            return MousePoint(
                timestamp: t * duration,
                position: CGPoint(x: x, y: y)
            )
        }
    }

    static func defaultPath() -> LinePath {
        let mouseLocation = CGEvent(source: nil)?.location ?? CGPoint(x: 500, y: 500)
        return LinePath(
            start: CGPoint(x: mouseLocation.x - 100, y: mouseLocation.y),
            end: CGPoint(x: mouseLocation.x + 100, y: mouseLocation.y),
            duration: 2.0
        )
    }
}
