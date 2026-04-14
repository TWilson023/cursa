import CoreGraphics

struct CirclePath: MousePath {
    let center: CGPoint
    let radius: Double
    let duration: Double
    let isLooping = true

    var points: [MousePoint] {
        let stepCount = max(Int(duration * 60), 60)
        return (0...stepCount).map { i in
            let t = Double(i) / Double(stepCount)
            let angle = t * 2 * .pi
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)
            return MousePoint(
                timestamp: t * duration,
                position: CGPoint(x: x, y: y)
            )
        }
    }

    static func defaultPath() -> CirclePath {
        let mouseLocation = CGEvent(source: nil)?.location ?? CGPoint(x: 500, y: 500)
        return CirclePath(center: mouseLocation, radius: 100, duration: 3.0)
    }
}
